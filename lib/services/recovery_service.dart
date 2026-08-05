import 'dart:convert';
import 'package:localstore/localstore.dart';
import '../models/live_game.dart';
import '../models/game.dart';
import '../models/tournament.dart';
import '../models/chip_color.dart';

class RecoveryService {
  static final _db = Localstore.instance;
  static const _collection = 'recovery';
  static const _docId = 'active_game';

  static Future<void> saveGame(LiveGame game) async {
    final data = _liveGameToMap(game);
    data['lastSavedAt'] = DateTime.now().toIso8601String();
    await _db.collection(_collection).doc(_docId).set(data);
  }

  static Future<void> clearGame() async {
    await _db.collection(_collection).doc(_docId).delete();
  }

  static Future<LiveGame?> loadGame() async {
    final data = await _db.collection(_collection).doc(_docId).get();
    if (data == null) return null;

    try {
      final game = _liveGameFromMap(data);
      final lastSavedString = data['lastSavedAt'] as String?;
      if (lastSavedString != null) {
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
      print('Error recovering game: $e');
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
      'dealerPlayerId': game.dealerPlayerId,
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
      announcements: (map['announcements'] as List).map((e) => _announcementFromMap(e)).toList(),
      totalChipsInPlay: map['totalChipsInPlay'],
      pendingGuests: (map['pendingGuests'] as List).map((e) => _playerFromMap(e)).toList(),
      finishOrder: List<String>.from(map['finishOrder'] ?? []),
      speedRecommendation: map['speedRecommendation'] != null
          ? SpeedRecommendation.values.firstWhere((e) => e.name == map['speedRecommendation'])
          : null,
      settlementConfirmed: map['settlementConfirmed'] ?? false,
      dealerPlayerId: map['dealerPlayerId'],
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
      'anteEnabled': settings.anteEnabled,
      'anteAfterLevel': settings.anteAfterLevel,
      'organizerPct': settings.organizerPct,
      'chipSet': settings.chipSet.map(_chipColorToMap).toList(),
      'chipSetName': settings.chipSetName,
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
      anteEnabled: map['anteEnabled'] ?? false,
      anteAfterLevel: map['anteAfterLevel'] ?? 0,
      organizerPct: map['organizerPct'] ?? 0,
      chipSet: (map['chipSet'] as List).map((e) => _chipColorFromMap(e)).toList(),
      chipSetName: map['chipSetName'] ?? '',
    );
  }

  static Map<String, dynamic> _tournamentStructureToMap(TournamentStructure struct) {
    return {
      'startingStack': struct.startingStack,
      'chipPlan': struct.chipPlan.map(_chipPlanEntryToMap).toList(),
      'rebuyStack': struct.rebuyStack,
      'rebuyChipPlan': struct.rebuyChipPlan.map(_chipPlanEntryToMap).toList(),
      'addOnStack': struct.addOnStack,
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

  static TournamentStructure _tournamentStructureFromMap(Map<String, dynamic> map) {
    return TournamentStructure(
      startingStack: map['startingStack'],
      chipPlan: (map['chipPlan'] as List).map((e) => _chipPlanEntryFromMap(e)).toList(),
      rebuyStack: map['rebuyStack'],
      rebuyChipPlan: (map['rebuyChipPlan'] as List).map((e) => _chipPlanEntryFromMap(e)).toList(),
      addOnStack: map['addOnStack'],
      levels: (map['levels'] as List).map((e) => _blindLevelFromMap(e)).toList(),
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
          ? Rsvp.values.firstWhere((e) => e.name == map['rsvp'], orElse: () => Rsvp.maybe)
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
    return {
      'color': c.color,
      'hex': c.hex,
      'value': c.value,
      'count': c.count,
    };
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
    return {
      'place': p.place,
      'amount': p.amount,
    };
  }

  static Prize _prizeFromMap(Map<String, dynamic> map) {
    return Prize(
      place: map['place'],
      amount: map['amount'],
    );
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
}
