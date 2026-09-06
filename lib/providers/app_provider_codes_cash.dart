/// AppProvider: Join code + cash game domain mixin.
///
/// Extracted verbatim from app_provider.dart (`// ── Code lookup ──` + `// ── Cash game ──`). Do not change business logic.
part of 'app_provider.dart';

extension AppProviderCodesCash on AppProvider {
  /// Extracts a bare join code from anything the user might enter: a raw code
  /// (`FRIDAY7`), a full invite link
  /// (`https://poker-night-tools.web.app/join-group?code=FRIDAY7`), a game link
  /// (`.../game/FP2608`) or a QR payload. Returns an upper-cased `[A-Z0-9]`
  /// string, or `''` when nothing code-like is present.
  String extractJoinCode(String input) {
    var s = input.trim();
    if (s.isEmpty) return '';

    final uri = Uri.tryParse(s);
    if (uri != null && uri.hasScheme) {
      final q = uri.queryParameters['code'];
      if (q != null && q.isNotEmpty) {
        s = q;
      } else if (uri.pathSegments.isNotEmpty) {
        // `/game/FP2608`, `/join/FP2608`, `/join-group/FRIDAY7`
        s = uri.pathSegments.last;
      }
    } else if (s.contains('code=')) {
      s = s.split('code=').last.split('&').first;
    } else if (s.contains('/')) {
      s = s.split('/').last.split('?').first.split('#').first;
    }

    return s.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
  }

  /// Classifies a join code (or invite link / QR payload) as a group code, a
  /// game code or a TV code — without joining or subscribing to anything.
  /// The unified join screen uses this to route guests and signed-in users to
  /// the right flow. Safe to call unauthenticated (join codes are world-
  /// readable by design).
  Future<JoinCodeResolution> resolveJoinCode(String input) async {
    final code = extractJoinCode(input);
    if (code.isEmpty) return const JoinCodeResolution(JoinCodeKind.notFound, '');
    if (!_backendUp) return JoinCodeResolution(JoinCodeKind.error, code);
    if (!_consumeCodeLookupSlot()) {
      return JoinCodeResolution(JoinCodeKind.rateLimited, code);
    }
    try {
      final data = await _repo.peekJoinCode(code);
      if (data == null) return JoinCodeResolution(JoinCodeKind.notFound, code);
      final gameId = data['gameId'] as String?;
      if (gameId == null || gameId.isEmpty) {
        return JoinCodeResolution(JoinCodeKind.group, code);
      }
      final kind = (data['kind'] as String?) ?? 'game';
      return JoinCodeResolution(
        kind == 'tv' ? JoinCodeKind.tv : JoinCodeKind.game,
        code,
      );
    } catch (e) {
      debugPrint('resolveJoinCode failed: $e');
      return JoinCodeResolution(JoinCodeKind.error, code);
    }
  }

  bool _consumeCodeLookupSlot() {
    final now = DateTime.now();
    _codeLookupTimes
        .removeWhere((t) => now.difference(t) > const Duration(minutes: 1));
    if (_codeLookupTimes.length >= 10) return false;
    _codeLookupTimes.add(now);
    return true;
  }

  /// Resolves a public/TV join code through Firestore and subscribes the
  /// matching feed. TVs and guests read the sanitized `publicGames/{id}`
  /// projections (never the raw game doc); the returned result tells the
  /// caller which screen to open. Returns [CodeLookupResult.notFound] for
  /// unknown codes or when no backend is available.
  Future<CodeLookupResult> enterGameCode(String code) async {
    if (!_backendUp) return CodeLookupResult.notFound;
    if (!_consumeCodeLookupSlot()) return CodeLookupResult.rateLimited;
    try {
      final hit = await _repo.findGameByCode(code);
      if (hit == null) return CodeLookupResult.notFound;

      _lookupSub?.cancel();
      if (hit.kind == 'game' && _isGameAuthority) {
        // Admins can follow the raw document.
        _lookupSub =
            _repo.gameDocSnapshots(hit.gid, hit.gameId, isAdmin: true).listen((snap) {
          final data = snap.data();
          if (!snap.exists || data == null) return;
          try {
            _clearUndoStack();
            final remote =
                liveGameFromFirestoreDoc(Map<String, dynamic>.from(data));
            _currentGame =
                _withPendingCheckInOverlay(_withOwnRsvpOverlay(remote));
            _lastSavedGame = remote;
            notifyListeners();
          } catch (e) {
            debugPrint('code-lookup game decode failed: $e');
          }
        }, onError: (Object e) => debugPrint('lookup stream error: $e'));
      } else {
        // Guests / TVs / Members (F-001 Fix): sanitized projection feed.
        final projectionKey = hit.kind == 'tv' ? 'tv' : (hit.kind == 'game' ? 'player' : 'guest');
        _lookupSub = _repo.publicGameStream(hit.gameId).listen((doc) {
          final payload = doc[projectionKey] as Map<String, dynamic>?;
          if (payload == null) return;
          try {
            _clearUndoStack();
            _currentGame = _withPendingCheckInOverlay(_withOwnRsvpOverlay(
              liveGameFromMap(Map<String, dynamic>.from(payload as Map)),
            ));
            notifyListeners();
          } catch (e) {
            debugPrint('projection decode failed: $e');
          }
        }, onError: (Object e) => debugPrint('public stream error: $e'));
      }
      return hit.kind == 'tv'
          ? CodeLookupResult.tv
          : CodeLookupResult.game;
    } catch (e) {
      debugPrint('enterGameCode failed: $e');
      return CodeLookupResult.notFound;
    }
  }

  CashSession? get cashSession => _cashSession;

  List<CashSession> get cashHistory => List.unmodifiable(_cashHistory);

  void startCashGame(CashSessionSettings settings, List<String> playerNames) {
    _cashSession = CashSession(
      id: 'cash-${DateTime.now().millisecondsSinceEpoch}',
      settings: settings,
      isCompleted: false,
      startTime: DateTime.now(),
      players: List.generate(
        playerNames.length,
        (i) => CashPlayer(
          id: 'cp-${DateTime.now().millisecondsSinceEpoch}-$i',
          name: playerNames[i],
          stack: settings.minBuyIn,
          totalBuyIns: settings.minBuyIn,
          buyInCount: 1,
          cashedOut: 0,
        ),
      ),
    );
    notifyListeners();
  }

  /// Records a cash buy-in / rebuy for a player (or adds a brand-new player).
  /// Returns a validation message when the amount falls outside the session's
  /// [CashSessionSettings.minBuyIn]..[CashSessionSettings.maxBuyIn] bounds, or
  /// null on success.
  String? cashBuyIn(
    String playerIdOrName,
    double amount, {
    bool isNew = false,
  }) {
    final session = _cashSession;
    if (session == null) return 'No active cash session.';
    if (amount <= 0) return 'Amount must be positive.';
    final min = session.settings.minBuyIn;
    final max = session.settings.maxBuyIn;
    // No currency symbols in the primary interface (User Flow spec §3.4).
    if (amount < min) return 'Minimum buy-in is $min.';
    if (amount > max) return 'Maximum buy-in is $max.';
    if (isNew) {
      _cashSession = session.copyWith(
        players: [
          ...session.players,
          CashPlayer(
            id: 'cp-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}',
            name: playerIdOrName,
            stack: amount,
            totalBuyIns: amount,
            buyInCount: 1,
            cashedOut: 0,
          ),
        ],
      );
    } else {
      _cashSession = session.copyWith(
        players: session.players
            .map(
              (p) => p.id == playerIdOrName
                  ? p.copyWith(
                      stack: p.stack + amount,
                      totalBuyIns: p.totalBuyIns + amount,
                      buyInCount: p.buyInCount + 1,
                    )
                  : p,
            )
            .toList(),
      );
    }
    notifyListeners();
    return null;
  }

  void cashCashOut(String playerId, double amount) {
    final session = _cashSession;
    if (session == null) return;
    _cashSession = session.copyWith(
      players: session.players
          .map(
            (p) =>
                p.id == playerId ? p.copyWith(cashedOut: amount, stack: 0, hasCashedOut: true) : p,
          )
          .toList(),
    );
    notifyListeners();
  }

  /// Corrects an incorrectly entered buy-in, top-up or cash-out (checklist
  /// 17-020 / 17-028 / 20-047). All totals are recomputed from the corrected
  /// fields; stack/total/buyInCount/cashedOut that are null are left as-is.
  void cashEditPlayer(
    String playerId, {
    double? stack,
    double? totalBuyIns,
    int? buyInCount,
    double? cashedOut,
    bool? hasCashedOut,
  }) {
    final session = _cashSession;
    if (session == null) return;
    _cashSession = session.copyWith(
      players: session.players
          .map(
            (p) => p.id == playerId
                ? CashPlayer(
                    id: p.id,
                    name: p.name,
                    stack: stack ?? p.stack,
                    totalBuyIns: totalBuyIns ?? p.totalBuyIns,
                    buyInCount: buyInCount ?? p.buyInCount,
                    cashedOut: cashedOut ?? p.cashedOut,
                    hasCashedOut: hasCashedOut ?? p.hasCashedOut,
                  )
                : p,
          )
          .toList(),
    );
    notifyListeners();
  }

  void endCashGame({String? unresolvedNote}) {
    final session = _cashSession;
    if (session == null) return;
    _cashSession = session.copyWith(
      isCompleted: true,
      unresolvedNote: unresolvedNote,
    );
    _cashHistory = [_cashSession!, ..._cashHistory];
    notifyListeners();
    final gid = _currentGroupId ?? _currentGame?.groupId;
    final uid = _repo.currentUid;
    if (_backendUp && gid != null && uid != null) {
      unawaited(_repo
          .saveCashSession(gid, _cashSession!)
          .catchError(
              (Object e) => debugPrint('saveCashSession failed: $e')));
    }
    clearCashSession();
  }

  /// Discards the current cash session so a fresh game can be started.
  void clearCashSession() {
    _cashSession = null;
    RecoveryService.clearCashSession();
    notifyListeners();
  }
}