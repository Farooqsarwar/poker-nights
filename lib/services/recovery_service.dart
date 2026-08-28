import 'package:flutter/foundation.dart';
import 'package:localstore/localstore.dart';
import '../models/cash_game.dart';
import '../models/live_game.dart';
import '../utils/model_codec.dart';

/// A guest's own check-in session stored on the guest device so the guest can
/// recover the same approved session after a refresh (checklist 07-030).
class GuestSession {
  const GuestSession({
    required this.gameId,
    required this.name,
    required this.inviterId,
    required this.slot,
  });

  final String gameId;
  final String name;
  final String inviterId;
  final int slot;

  Map<String, dynamic> toMap() => {
    'gameId': gameId,
    'name': name,
    'inviterId': inviterId,
    'slot': slot,
  };

  static GuestSession? fromMap(Map<String, dynamic> map) {
    final gameId = map['gameId'] as String?;
    final name = map['name'] as String?;
    final inviterId = map['inviterId'] as String?;
    final slot = map['slot'] as int?;
    if (gameId == null || name == null || inviterId == null || slot == null) {
      return null;
    }
    return GuestSession(
      gameId: gameId,
      name: name,
      inviterId: inviterId,
      slot: slot,
    );
  }
}

/// Device-local crash recovery store. All model serialization is delegated to
/// the shared codecs in `model_codec.dart` so local persistence and the cloud
/// repository always speak the exact same wire format.
class RecoveryService {
  static final _db = Localstore.instance;
  static const _collection = 'recovery';
  static const _docId = 'active_game';

  /// Timestamp of the most recently loaded snapshot, so the UI can offer
  /// "Restore active tournament — last saved 21:43" (Tech spec §20.1).
  static DateTime? _lastSavedAt;
  static DateTime? get lastSavedAt => _lastSavedAt;

  static Future<void> saveGame(LiveGame game) async {
    try {
      final data = liveGameToMap(game);
      data['lastSavedAt'] = DateTime.now().toIso8601String();
      await _db.collection(_collection).doc(_docId).set(data);
    } catch (e) {
      debugPrint('RecoveryService: could not persist active game: $e');
    }
  }

  // ── Cash session (active, admin device) ────────────────────────────────────
  static const _cashDocId = 'active_cash';

  static Future<void> saveCashSession(CashSession session) async {
    try {
      final data = cashSessionToMap(session);
      data['lastSavedAt'] = DateTime.now().toIso8601String();
      await _db.collection(_collection).doc(_cashDocId).set(data);
    } catch (e) {
      debugPrint('RecoveryService: could not persist cash session: $e');
    }
  }

  static Future<void> clearCashSession() async {
    try {
      await _db.collection(_collection).doc(_cashDocId).delete();
    } catch (e) {
      debugPrint('RecoveryService: could not clear cash session: $e');
    }
  }

  static Future<CashSession?> loadCashSession() async {
    final data = await _db.collection(_collection).doc(_cashDocId).get();
    if (data == null) return null;
    try {
      return cashSessionFromMap(Map<String, dynamic>.from(data));
    } catch (e) {
      debugPrint('Error recovering cash session: $e');
      return null;
    }
  }

  // ── Guest check-in session (guest device) ──────────────────────────────────
  static const _guestDocId = 'guest_session';

  static Future<void> saveGuestSession(GuestSession session) async {
    try {
      await _db.collection(_collection).doc(_guestDocId).set(session.toMap());
    } catch (e) {
      debugPrint('RecoveryService: could not persist guest session: $e');
    }
  }

  static Future<void> clearGuestSession() async {
    try {
      await _db.collection(_collection).doc(_guestDocId).delete();
    } catch (e) {
      debugPrint('RecoveryService: could not clear guest session: $e');
    }
  }

  static Future<GuestSession?> loadGuestSession() async {
    final data = await _db.collection(_collection).doc(_guestDocId).get();
    if (data == null) return null;
    try {
      return GuestSession.fromMap(Map<String, dynamic>.from(data));
    } catch (e) {
      debugPrint('Error recovering guest session: $e');
      return null;
    }
  }

  static Future<void> clearGame() async {
    try {
      await _db.collection(_collection).doc(_docId).delete();
    } catch (e) {
      debugPrint('RecoveryService: could not clear active game: $e');
    }
  }

  static Future<LiveGame?> loadGame() async {
    final data = await _db.collection(_collection).doc(_docId).get();
    if (data == null) return null;

    try {
      final game = liveGameFromMap(Map<String, dynamic>.from(data));
      final lastSavedString = data['lastSavedAt'] as String?;
      if (lastSavedString != null) {
        _lastSavedAt = DateTime.parse(lastSavedString);
        // Tech spec §4.3: persist timestamps and derive remaining time.
        // When levelEndTime is preserved, the computed getter handles the
        // derivation — no manual adjustment needed.  Only fall back to the
        // secondsRemaining adjustment when the timer was paused (no
        // levelEndTime) so the paused value stays accurate across recovery.
        if (game.timerRunning && game.levelEndTime != null) {
          // levelEndTime is preserved via the codec; the computed
          // currentSecondsRemaining getter will derive the correct remaining
          // time from the wall clock.  No modification needed.
          return game;
        }
        if (!game.timerRunning) {
          // Timer was paused — secondsRemaining is the source of truth and
          // does not need adjustment (no time elapsed against the clock).
          return game;
        }
      }
      return game;
    } catch (e) {
      // In case of parsing error, return null to avoid breaking the app.
      debugPrint('Error recovering game: $e');
      return null;
    }
  }
}
