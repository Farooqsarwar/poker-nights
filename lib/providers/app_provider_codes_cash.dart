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
            if (!_disposed) notifyListeners();
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
            if (!_disposed) notifyListeners();
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

  /// Games finished with no group selected, newest first (History tags them
  /// "Solo").
  List<CashSession> get soloHistory {
    return [..._soloHistory]..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  void startCashGame(CashSessionSettings settings, List<String> playerNames) {
    _cashUndoSnapshot = null;
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
          stack: settings.minBuyIn * settings.chipValue,
          totalBuyIns: settings.minBuyIn * settings.chipValue,
          buyInCount: 1,
          cashedOut: 0,
        ),
      ),
    );
    if (!_disposed) notifyListeners();
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
    if (amount < min) return 'Minimum buy-in is ${_cashNum(min)}.';
    if (amount > max) return 'Maximum buy-in is ${_cashNum(max)}.';
    _cashUndoSnapshot = session;
    // Chips are typed; the ledger keeps money (chips x chip value, D1).
    final value = amount * session.settings.chipValue;
    if (isNew) {
      _cashSession = session.copyWith(
        players: [
          ...session.players,
          CashPlayer(
            id: 'cp-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}',
            name: playerIdOrName,
            stack: value,
            totalBuyIns: value,
            buyInCount: 1,
            cashedOut: 0,
          ),
        ],
      );
    } else {
      // A buy-in for somebody who already cashed out is a rejoin: the row
      // reopens and keeps its earlier cash-out, so the whole-session net holds.
      _cashSession = session.copyWith(
        players: session.players
            .map(
              (p) => p.id == playerIdOrName
                  ? p.copyWith(
                      stack: p.stack + value,
                      totalBuyIns: p.totalBuyIns + value,
                      buyInCount: p.buyInCount + 1,
                      hasCashedOut: false,
                    )
                  : p,
            )
            .toList(),
      );
    }
    if (!_disposed) notifyListeners();
    return null;
  }

  static String _cashNum(double n) =>
      n == n.roundToDouble() ? n.round().toString() : n.toString();

  /// Adds chips to a seated player (D2 "Top-up"). Unlike a buy-in it has no
  /// min/max: the host picks any amount. Returns a message on refusal.
  String? cashTopUp(String playerId, double amount) {
    final session = _cashSession;
    if (session == null) return 'No active cash session.';
    if (amount <= 0) return 'Amount must be positive.';
    final player = session.players.where((p) => p.id == playerId).firstOrNull;
    if (player == null || player.hasCashedOut) {
      return 'That player is not seated.';
    }
    _cashUndoSnapshot = session;
    final value = amount * session.settings.chipValue;
    _cashSession = session.copyWith(
      players: session.players
          .map(
            (p) => p.id == playerId
                ? p.copyWith(
                    stack: p.stack + value,
                    totalBuyIns: p.totalBuyIns + value,
                  )
                : p,
          )
          .toList(),
    );
    if (!_disposed) notifyListeners();
    return null;
  }

  /// Takes back the last buy-in, top-up or cash-out (T125 Undo).
  void undoCashAction() {
    final snapshot = _cashUndoSnapshot;
    if (snapshot == null) return;
    _cashSession = snapshot;
    _cashUndoSnapshot = null;
    if (!_disposed) notifyListeners();
  }

  /// D2: ending early "asks: Cash out everyone still seated at their current
  /// stack?" -- this is the yes. Returns the first refusal, if any.
  String? cashOutAllSeated() {
    final session = _cashSession;
    if (session == null) return null;
    for (final p in session.players.where((p) => !p.hasCashedOut).toList()) {
      final current = _cashSession!.players.firstWhere((x) => x.id == p.id);
      final chips = current.stack / session.settings.chipValue;
      final error = cashCashOut(p.id, chips);
      if (error != null) {
        _cashSession = session;
        _cashUndoSnapshot = null;
        if (!_disposed) notifyListeners();
        return error;
      }
    }
    _cashUndoSnapshot = session;
    return null;
  }

  /// Records a cash-out, or refuses it and returns the message to show.
  ///
  /// F2.10 / G2.3 row 34: "Settle-up handles up to 16 people with a non-zero
  /// balance at once. If cashing someone out would make a 17th open balance,
  /// that cash-out is blocked with 'Settle-up handles up to 16 people still
  /// owed or owing - settle someone first.'"
  ///
  /// The refusal is the point. [CashSettlement] would happily fall back to a
  /// still-correct-but-not-minimal greedy pairing above its exact-DP limit, so
  /// without this guard a 20-handed table would quietly produce a longer
  /// transfer list than the spec promises rather than asking the host to settle
  /// someone first.
  ///
  /// Returns null when the cash-out was recorded.
  String? cashCashOut(String playerId, double amount) {
    final session = _cashSession;
    if (session == null) return null;
    final player = session.players.where((p) => p.id == playerId).firstOrNull;
    if (player == null) return null;

    // Count the open balances as they would stand AFTER this cash-out, so the
    // player being cashed out contributes their post-cash-out net rather than
    // the pre-cash-out one. Compared in whole cents: these are doubles
    // accumulated through repeated buy-ins and top-ups, and a raw `!= 0`
    // would read float noise as an open balance.
    final value = amount * session.settings.chipValue;
    var open = 0;
    for (final p in session.players) {
      final netCents = p.id == playerId
          ? ((p.cashedOut + value - p.totalBuyIns) * 100).round()
          : (p.net * 100).round();
      if (netCents != 0) open++;
    }
    if (open > CashSettlement.maxExactPeople) {
      return 'Settle-up handles up to ${CashSettlement.maxExactPeople} people '
          'still owed or owing - settle someone first.';
    }

    _cashUndoSnapshot = session;
    // Accumulates: a rejoin followed by a second cash-out adds to the first.
    _cashSession = session.copyWith(
      players: session.players
          .map(
            (p) => p.id == playerId
                ? p.copyWith(
                    cashedOut: p.cashedOut + value,
                    stack: 0,
                    hasCashedOut: true,
                  )
                : p,
          )
          .toList(),
    );
    if (!_disposed) notifyListeners();
    return null;
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
    if (!_disposed) notifyListeners();
  }

  String? endCashGame({String? unresolvedNote}) {
    final session = _cashSession;
    if (session == null) return 'No active cash session.';
    if (session.difference.abs() > 0.01 &&
        (unresolvedNote == null || unresolvedNote.trim().isEmpty)) {
      return 'Buy-ins and cash-outs do not match. Correct the records or add a note explaining the difference before completing.';
    }
    _cashSession = session.copyWith(
      isCompleted: true,
      unresolvedNote: (unresolvedNote == null || unresolvedNote.trim().isEmpty)
          ? null
          : unresolvedNote.trim(),
    );
    // Group cash records are readable by the group's admins only (they hold
    // everyone's money), so a member's session is kept as their own Solo record.
    final groupId = _currentGroupId ?? _currentGame?.groupId;
    final gid = groupId != null && isAdmin ? groupId : null;
    final uid = _repo.currentUid;
    if (gid == null) {
      _soloHistory = [_cashSession!, ..._soloHistory];
    } else {
      _cashHistory = [_cashSession!, ..._cashHistory];
    }
    if (!_disposed) notifyListeners();
    if (_backendUp && gid == null && uid != null) {
      unawaited(_repo
          .saveSoloSession(uid, _cashSession!)
          .catchError(
              (Object e) => debugPrint('saveSoloSession failed: $e')));
    } else if (_backendUp && gid != null && uid != null) {
      unawaited(_repo
          .saveCashSession(gid, _cashSession!)
          .catchError(
              (Object e) => debugPrint('saveCashSession failed: $e')));
    }
    clearCashSession();
    return null;
  }

  /// Discards the current cash session so a fresh game can be started.
  void clearCashSession() {
    _cashSession = null;
    _cashUndoSnapshot = null;
    RecoveryService.clearCashSession();
    if (!_disposed) notifyListeners();
  }
}