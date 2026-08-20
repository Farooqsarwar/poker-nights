import 'package:flutter/foundation.dart';
import 'package:localstore/localstore.dart';
import '../models/cash_game.dart';
import '../models/live_game.dart';
import '../models/game.dart';
import '../models/tournament.dart';
import '../models/chip_color.dart';

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
      final data = _liveGameToMap(game);
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
      final data = _cashSessionToMap(session);
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
      return _cashSessionFromMap(data);
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
      return GuestSession.fromMap(data);
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
      final game = _liveGameFromMap(data);
      final lastSavedString = data['lastSavedAt'] as String?;
      if (lastSavedString != null) {
        _lastSavedAt = DateTime.parse(lastSavedString);
        final lastSavedAt = DateTime.parse(lastSavedString);
        if (game.timerRunning) {
          final elapsed = DateTime.now().difference(lastSavedAt).inSeconds;
          var remaining = game.secondsRemaining - elapsed;
          if (remaining < 0) remaining = 0;
          return game.copyWith(secondsRemaining: remaining);
        }
      }
      return game;
    } catch (e) {
      // In case of parsing error, return null to avoid breaking the app.
      debugPrint('Error recovering game: $e');
      return null;
    }
  }

  // --- Mappers ---

  static Map<String, dynamic> _liveGameToMap(LiveGame game) {
    return {
      'id': game.id,
      'groupId': game.groupId,
      'settings': _gameSettingsToMap(game.settings),
      'structure': _tournamentStructureToMap(game.structure),
      'status': game.status.name,
      'publicCode': game.publicCode,
      'tvCode': game.tvCode,
      'currentLevel': game.currentLevel,
      'timerRunning': game.timerRunning,
      'secondsRemaining': game.secondsRemaining,
      'players': game.players.map(_playerToMap).toList(),
      'chat': game.chat.map(_chatMessageToMap).toList(),
      'announcements': game.announcements.map(_announcementToMap).toList(),
      'totalChipsInPlay': game.totalChipsInPlay,
      'pendingGuests': game.pendingGuests.map(_playerToMap).toList(),
      'finishOrder': game.finishOrder,
      'speedRecommendation': game.speedRecommendation?.name,
      'settlementConfirmed': game.settlementConfirmed,
      'seatingConfirmed': game.seatingConfirmed,
      'dealerPlayerId': game.dealerPlayerId,
      'guestSlots': game.guestSlots.map(_guestSlotToMap).toList(),
      'originalLevels': game.originalLevels?.map(_blindLevelToMap).toList(),
      'levelEndTime': game.levelEndTime?.toIso8601String(),
    };
  }

  static LiveGame _liveGameFromMap(Map<String, dynamic> map) {
    return LiveGame(
      id: map['id'],
      groupId: map['groupId'],
      settings: _gameSettingsFromMap(map['settings']),
      structure: _tournamentStructureFromMap(map['structure']),
      status: LiveGameStatus.values.firstWhere((e) => e.name == map['status']),
      publicCode: map['publicCode'],
      tvCode: map['tvCode'],
      currentLevel: map['currentLevel'],
      timerRunning: map['timerRunning'] ?? false,
      secondsRemaining: map['secondsRemaining'],
      players: (map['players'] as List).map((e) => _playerFromMap(e)).toList(),
      chat: (map['chat'] as List).map((e) => _chatMessageFromMap(e)).toList(),
      announcements: (map['announcements'] as List)
          .map((e) => _announcementFromMap(e))
          .toList(),
      totalChipsInPlay: map['totalChipsInPlay'],
      pendingGuests: (map['pendingGuests'] as List)
          .map((e) => _playerFromMap(e))
          .toList(),
      finishOrder: List<String>.from(map['finishOrder'] ?? []),
      speedRecommendation: map['speedRecommendation'] != null
          ? SpeedRecommendation.values.firstWhere(
              (e) => e.name == map['speedRecommendation'],
            )
          : null,
      settlementConfirmed: map['settlementConfirmed'] ?? false,
      seatingConfirmed: map['seatingConfirmed'] ?? false,
      dealerPlayerId: map['dealerPlayerId'],
      guestSlots:
          (map['guestSlots'] as List?)
              ?.map((e) => _guestSlotFromMap(e))
              .toList() ??
          const [],
      originalLevels: (map['originalLevels'] as List?)
          ?.map((e) => _blindLevelFromMap(e))
          .toList(),
      levelEndTime: map['levelEndTime'] != null
          ? DateTime.parse(map['levelEndTime'])
          : null,
    );
  }

  static Map<String, dynamic> _gameSettingsToMap(GameSettings settings) {
    return {
      'name': settings.name,
      'date': settings.date,
      'time': settings.time,
      'location': settings.location,
      'players': settings.players,
      'durationHours': settings.durationHours,
      'buyIn': settings.buyIn,
      'koEnabled': settings.koEnabled,
      'koAmount': settings.koAmount,
      'rebuys': settings.rebuys,
      'rebuysCloseLevel': settings.rebuysCloseLevel,
      'reEntry': settings.reEntry,
      'addOn': settings.addOn,
      'addOnCloseLevel': settings.addOnCloseLevel,
      'anteEnabled': settings.anteEnabled,
      'anteAfterLevel': settings.anteAfterLevel,
      'anteStyle': settings.anteStyle.name,
      'antePreference': settings.antePreference.name,
      'organizerPct': settings.organizerPct,
      'chipSet': settings.chipSet.map(_chipColorToMap).toList(),
      'chipSetName': settings.chipSetName,
      'announceEliminations': settings.announceEliminations,
      'forcePaidPlaces': settings.forcePaidPlaces,
      'rebuyCost': settings.rebuyCost,
      'addOnCost': settings.addOnCost,
      'locationPrivate': settings.locationPrivate,
    };
  }

  static GameSettings _gameSettingsFromMap(Map<String, dynamic> map) {
    return GameSettings(
      name: map['name'],
      date: map['date'],
      time: map['time'],
      location: map['location'],
      players: map['players'],
      durationHours: map['durationHours']?.toDouble() ?? 0.0,
      buyIn: map['buyIn'],
      koEnabled: map['koEnabled'] ?? false,
      koAmount: map['koAmount'] ?? 0,
      rebuys: map['rebuys'] ?? false,
      rebuysCloseLevel: map['rebuysCloseLevel'] ?? 0,
      reEntry: map['reEntry'] ?? false,
      addOn: map['addOn'] ?? false,
      addOnCloseLevel: map['addOnCloseLevel'] ?? 6,
      anteEnabled: map['anteEnabled'] ?? false,
      anteAfterLevel: map['anteAfterLevel'] ?? 0,
      anteStyle:
          AnteStyle.values.asNameMap()[map['anteStyle']] ?? AnteStyle.bigBlind,
      antePreference:
          AntePreference.values.asNameMap()[map['antePreference']] ??
          AntePreference.recommend,
      organizerPct: map['organizerPct'] ?? 0,
      chipSet: (map['chipSet'] as List)
          .map((e) => _chipColorFromMap(e))
          .toList(),
      chipSetName: map['chipSetName'] ?? '',
      announceEliminations: map['announceEliminations'] ?? false,
      forcePaidPlaces: map['forcePaidPlaces'],
      rebuyCost: map['rebuyCost'],
      addOnCost: map['addOnCost'],
      locationPrivate: map['locationPrivate'] ?? false,
    );
  }

  static Map<String, dynamic> _tournamentStructureToMap(
    TournamentStructure struct,
  ) {
    return {
      'startingStack': struct.startingStack,
      'chipPlan': struct.chipPlan.map(_chipPlanEntryToMap).toList(),
      'rebuyStack': struct.rebuyStack,
      'rebuyChipPlan': struct.rebuyChipPlan.map(_chipPlanEntryToMap).toList(),
      'addOnStack': struct.addOnStack,
      'addOnChipPlan': struct.addOnChipPlan.map(_chipPlanEntryToMap).toList(),
      'levels': struct.levels.map(_blindLevelToMap).toList(),
      'levelDuration': struct.levelDuration,
      'expectedFinishMins': struct.expectedFinishMins,
      'prizes': struct.prizes.map(_prizeToMap).toList(),
      'prizePool': struct.prizePool,
      'organizerAmount': struct.organizerAmount,
      'colorUpInstructions': struct.colorUpInstructions,
      'warnings': struct.warnings,
    };
  }

  static TournamentStructure _tournamentStructureFromMap(
    Map<String, dynamic> map,
  ) {
    return TournamentStructure(
      startingStack: map['startingStack'],
      chipPlan: (map['chipPlan'] as List)
          .map((e) => _chipPlanEntryFromMap(e))
          .toList(),
      rebuyStack: map['rebuyStack'],
      rebuyChipPlan: (map['rebuyChipPlan'] as List)
          .map((e) => _chipPlanEntryFromMap(e))
          .toList(),
      addOnStack: map['addOnStack'],
      addOnChipPlan:
          (map['addOnChipPlan'] as List?)
              ?.map((e) => _chipPlanEntryFromMap(e))
              .toList() ??
          const [],
      levels: (map['levels'] as List)
          .map((e) => _blindLevelFromMap(e))
          .toList(),
      levelDuration: map['levelDuration'],
      expectedFinishMins: map['expectedFinishMins'],
      prizes: (map['prizes'] as List).map((e) => _prizeFromMap(e)).toList(),
      prizePool: map['prizePool'],
      organizerAmount: map['organizerAmount'],
      colorUpInstructions: List<String>.from(map['colorUpInstructions'] ?? []),
      warnings: List<String>.from(map['warnings'] ?? []),
    );
  }

  static Map<String, dynamic> _playerToMap(Player p) {
    return {
      'id': p.id,
      'name': p.name,
      'isGuest': p.isGuest,
      'inviterId': p.inviterId,
      'guestSlot': p.guestSlot,
      'rsvp': p.rsvp?.name,
      'checkedIn': p.checkedIn,
      'confirmed': p.confirmed,
      'eliminated': p.eliminated,
      'eliminationPos': p.eliminationPos,
      'rebuys': p.rebuys,
      'reEntries': p.reEntries,
      'hasAddOn': p.hasAddOn,
      'knockouts': p.knockouts,
      'table': p.table,
      'seat': p.seat,
      'active': p.active,
    };
  }

  static Player _playerFromMap(Map<String, dynamic> map) {
    return Player(
      id: map['id'],
      name: map['name'],
      isGuest: map['isGuest'] ?? false,
      inviterId: map['inviterId'],
      guestSlot: map['guestSlot'],
      rsvp: map['rsvp'] != null
          ? Rsvp.values.firstWhere(
              (e) => e.name == map['rsvp'],
              orElse: () => Rsvp.maybe,
            )
          : null,
      checkedIn: map['checkedIn'] ?? false,
      confirmed: map['confirmed'] ?? false,
      eliminated: map['eliminated'] ?? false,
      eliminationPos: map['eliminationPos'],
      rebuys: map['rebuys'] ?? 0,
      reEntries: map['reEntries'] ?? 0,
      hasAddOn: map['hasAddOn'] ?? false,
      knockouts: map['knockouts'] ?? 0,
      table: map['table'] ?? 0,
      seat: map['seat'] ?? 0,
      active: map['active'] ?? true,
    );
  }

  static Map<String, dynamic> _chatMessageToMap(ChatMessage msg) {
    return {
      'id': msg.id,
      'authorId': msg.authorId,
      'authorName': msg.authorName,
      'body': msg.body,
      'timestamp': msg.timestamp.toIso8601String(),
      'deleted': msg.deleted,
      'pinned': msg.pinned,
    };
  }

  static ChatMessage _chatMessageFromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      authorId: map['authorId'],
      authorName: map['authorName'],
      body: map['body'],
      timestamp: DateTime.parse(map['timestamp']),
      deleted: map['deleted'] ?? false,
      pinned: map['pinned'] ?? false,
    );
  }

  static Map<String, dynamic> _guestSlotToMap(GuestSlot s) {
    return {
      'id': s.id,
      'inviterId': s.inviterId,
      'slot': s.slot,
      'guestName': s.guestName,
      'status': s.status.name,
    };
  }

  static GuestSlot _guestSlotFromMap(Map<String, dynamic> map) {
    return GuestSlot(
      id: map['id'],
      inviterId: map['inviterId'],
      slot: map['slot'],
      guestName: map['guestName'],
      status: GuestSlotStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => GuestSlotStatus.unclaimed,
      ),
    );
  }

  static Map<String, dynamic> _announcementToMap(Announcement ann) {
    return {
      'id': ann.id,
      'text': ann.text,
      'timestamp': ann.timestamp.toIso8601String(),
    };
  }

  static Announcement _announcementFromMap(Map<String, dynamic> map) {
    return Announcement(
      id: map['id'],
      text: map['text'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  static Map<String, dynamic> _blindLevelToMap(BlindLevel l) {
    return {
      'level': l.level,
      'sb': l.sb,
      'bb': l.bb,
      'ante': l.ante,
      'durationMins': l.durationMins,
    };
  }

  static BlindLevel _blindLevelFromMap(Map<String, dynamic> map) {
    return BlindLevel(
      level: map['level'],
      sb: map['sb'],
      bb: map['bb'],
      ante: map['ante'],
      durationMins: map['durationMins'],
    );
  }

  static Map<String, dynamic> _chipPlanEntryToMap(ChipPlanEntry c) {
    return {'color': c.color, 'hex': c.hex, 'value': c.value, 'count': c.count};
  }

  static ChipPlanEntry _chipPlanEntryFromMap(Map<String, dynamic> map) {
    return ChipPlanEntry(
      color: map['color'],
      hex: map['hex'],
      value: map['value'],
      count: map['count'],
    );
  }

  static Map<String, dynamic> _prizeToMap(Prize p) {
    return {'place': p.place, 'amount': p.amount};
  }

  static Prize _prizeFromMap(Map<String, dynamic> map) {
    return Prize(place: map['place'], amount: map['amount']);
  }

  static Map<String, dynamic> _chipColorToMap(ChipColor c) {
    return {
      'color': c.color,
      'hex': c.hex,
      'value': c.value,
      'quantity': c.quantity,
    };
  }

  static ChipColor _chipColorFromMap(Map<String, dynamic> map) {
    return ChipColor(
      color: map['color'],
      hex: map['hex'],
      value: map['value'],
      quantity: map['quantity'],
    );
  }

  // --- Cash session mappers ---

  static Map<String, dynamic> _cashSessionToMap(CashSession session) {
    return {
      'id': session.id,
      'settings': _cashSettingsToMap(session.settings),
      'isCompleted': session.isCompleted,
      'startTime': session.startTime.toIso8601String(),
      'unresolvedNote': session.unresolvedNote,
      'players': session.players.map(_cashPlayerToMap).toList(),
    };
  }

  static CashSession _cashSessionFromMap(Map<String, dynamic> map) {
    return CashSession(
      id: map['id'],
      settings: _cashSettingsFromMap(map['settings']),
      isCompleted: map['isCompleted'] ?? false,
      startTime: DateTime.parse(map['startTime']),
      unresolvedNote: map['unresolvedNote'],
      players: (map['players'] as List)
          .map((e) => _cashPlayerFromMap(e))
          .toList(),
    );
  }

  static Map<String, dynamic> _cashSettingsToMap(CashSessionSettings s) {
    return {
      'name': s.name,
      'date': s.date,
      'location': s.location,
      'smallBlind': s.smallBlind,
      'bigBlind': s.bigBlind,
      'minBuyIn': s.minBuyIn,
      'maxBuyIn': s.maxBuyIn,
      'currency': s.currency,
      'maxPlayers': s.maxPlayers,
      'rakePct': s.rakePct,
    };
  }

  static CashSessionSettings _cashSettingsFromMap(Map<String, dynamic> map) {
    return CashSessionSettings(
      name: map['name'],
      date: map['date'],
      location: map['location'],
      smallBlind: (map['smallBlind'] as num).toDouble(),
      bigBlind: (map['bigBlind'] as num).toDouble(),
      minBuyIn: (map['minBuyIn'] as num).toDouble(),
      maxBuyIn: (map['maxBuyIn'] as num).toDouble(),
      currency: map['currency'],
      maxPlayers: map['maxPlayers'] ?? 10,
      rakePct: (map['rakePct'] as num?)?.toDouble() ?? 0,
    );
  }

  static Map<String, dynamic> _cashPlayerToMap(CashPlayer p) {
    return {
      'id': p.id,
      'name': p.name,
      'stack': p.stack,
      'totalBuyIns': p.totalBuyIns,
      'buyInCount': p.buyInCount,
      'cashedOut': p.cashedOut,
    };
  }

  static CashPlayer _cashPlayerFromMap(Map<String, dynamic> map) {
    return CashPlayer(
      id: map['id'],
      name: map['name'],
      stack: (map['stack'] as num).toDouble(),
      totalBuyIns: (map['totalBuyIns'] as num).toDouble(),
      buyInCount: map['buyInCount'] ?? 1,
      cashedOut: (map['cashedOut'] as num?)?.toDouble() ?? 0,
    );
  }
}
