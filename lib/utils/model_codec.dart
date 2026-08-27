import '../models/app_notification.dart';
import '../models/cash_game.dart';
import '../models/chip_color.dart';
import '../models/game.dart';
import '../models/group.dart';
import '../models/live_game.dart';
import '../models/table_settings.dart';
import '../models/tournament.dart';
import '../models/tournament_preset.dart';
import '../models/user.dart';

/// Canonical model ⇄ map codecs shared by the local recovery store and the
/// cloud repository so both persistence layers can never drift apart.
///
/// Conventions:
///  * enums are stored as their `.name` string and parsed with a safe fallback
///  * DateTime values are stored as ISO-8601 strings
///  * numeric doubles are re-hydrated through `num.toDouble()`
///
/// History lists are capped while encoding so a stored document can never
/// grow unbounded; the in-memory session keeps the full lists.
const int kMaxEncodedAnnouncements = 100;
const int kMaxEncodedAuditRecords = 200;

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  if (name is String) {
    for (final v in values) {
      if (v.name == name) return v;
    }
  }
  return fallback;
}

String? _nullOrIso(DateTime? value) => value?.toIso8601String();

DateTime? _isoOrNull(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

List<Map<String, dynamic>> _mapList(Iterable<Object?> items) => [
      for (final item in items) Map<String, dynamic>.from(item as Map),
    ];

// ─────────────────────────────────────────────────────────────────────────────
// Users
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> userStatsToMap(UserStats s) => {
      'played': s.played,
      'wins': s.wins,
      'podium': s.podium,
      'avgFinish': s.avgFinish,
      'knockouts': s.knockouts,
    };

UserStats userStatsFromMap(Map<String, dynamic> m) => UserStats(
      played: (m['played'] as num?)?.toInt() ?? 0,
      wins: (m['wins'] as num?)?.toInt() ?? 0,
      podium: (m['podium'] as num?)?.toInt() ?? 0,
      avgFinish: (m['avgFinish'] as num?)?.toDouble() ?? 0,
      knockouts: (m['knockouts'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> appUserToMap(AppUser u) => {
      'id': u.id,
      'name': u.name,
      'email': u.email,
      'isAdmin': u.isAdmin,
      'stats': userStatsToMap(u.stats),
      'fcmTokens': u.fcmTokens,
      'isCoAdmin': u.isCoAdmin,
    };

AppUser appUserFromMap(Map<String, dynamic> m) => AppUser(
      id: m['id'] as String,
      name: (m['name'] as String?) ?? '',
      email: (m['email'] as String?) ?? '',
      isAdmin: (m['isAdmin'] as bool?) ?? false,
      stats: userStatsFromMap(Map<String, dynamic>.from(m['stats'] as Map)),
      fcmTokens: List<String>.from(m['fcmTokens'] as List? ?? const []),
      isCoAdmin: (m['isCoAdmin'] as bool?) ?? false,
    );

// ─────────────────────────────────────────────────────────────────────────────
// Table settings
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> tableSettingsToMap(TableSettings s) => {
      'maxPerTable': s.maxPerTable,
      'randomizeByDefault': s.randomizeByDefault,
    };

TableSettings tableSettingsFromMap(Map<String, dynamic> m) => TableSettings(
      maxPerTable: (m['maxPerTable'] as num?)?.toInt() ??
          TableSettings.fallback.maxPerTable,
      randomizeByDefault: (m['randomizeByDefault'] as bool?) ??
          TableSettings.fallback.randomizeByDefault,
    );

// ─────────────────────────────────────────────────────────────────────────────
// Chips
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> chipColorToMap(ChipColor c) => {
      'color': c.color,
      'hex': c.hex,
      'value': c.value,
      'quantity': c.quantity,
    };

ChipColor chipColorFromMap(Map<String, dynamic> m) => ChipColor(
      color: (m['color'] as String?) ?? '',
      hex: (m['hex'] as num?)?.toInt() ?? 0,
      value: (m['value'] as num?)?.toInt() ?? 0,
      quantity: (m['quantity'] as num?)?.toInt() ?? 0,
    );

// ─────────────────────────────────────────────────────────────────────────────
// Tournament structure
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> blindLevelToMap(BlindLevel l) => {
      'level': l.level,
      'sb': l.sb,
      'bb': l.bb,
      'ante': l.ante,
      'durationMins': l.durationMins,
    };

BlindLevel blindLevelFromMap(Map<String, dynamic> m) => BlindLevel(
      level: (m['level'] as num?)?.toInt() ?? 1,
      sb: (m['sb'] as num?)?.toInt() ?? 0,
      bb: (m['bb'] as num?)?.toInt() ?? 0,
      ante: (m['ante'] as num?)?.toInt(),
      durationMins: (m['durationMins'] as num?)?.toInt() ?? 15,
    );

Map<String, dynamic> chipPlanEntryToMap(ChipPlanEntry c) =>
    {'color': c.color, 'hex': c.hex, 'value': c.value, 'count': c.count};

ChipPlanEntry chipPlanEntryFromMap(Map<String, dynamic> m) => ChipPlanEntry(
      color: (m['color'] as String?) ?? '',
      hex: (m['hex'] as num?)?.toInt() ?? 0,
      value: (m['value'] as num?)?.toInt() ?? 0,
      count: (m['count'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> prizeToMap(Prize p) => {'place': p.place, 'amount': p.amount};

Prize prizeFromMap(Map<String, dynamic> m) => Prize(
      place: (m['place'] as num?)?.toInt() ?? 0,
      amount: (m['amount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> tournamentStructureToMap(TournamentStructure s) => {
      'startingStack': s.startingStack,
      'chipPlan': s.chipPlan.map(chipPlanEntryToMap).toList(),
      'rebuyStack': s.rebuyStack,
      'rebuyChipPlan': s.rebuyChipPlan.map(chipPlanEntryToMap).toList(),
      'addOnStack': s.addOnStack,
      'addOnChipPlan': s.addOnChipPlan.map(chipPlanEntryToMap).toList(),
      'levels': s.levels.map(blindLevelToMap).toList(),
      'levelDuration': s.levelDuration,
      'expectedFinishMins': s.expectedFinishMins,
      'prizes': s.prizes.map(prizeToMap).toList(),
      'prizePool': s.prizePool,
      'organizerAmount': s.organizerAmount,
      'colorUpInstructions': List<String>.from(s.colorUpInstructions),
      'warnings': List<String>.from(s.warnings),
    };

TournamentStructure tournamentStructureFromMap(Map<String, dynamic> m) =>
    TournamentStructure(
      startingStack: (m['startingStack'] as num?)?.toInt() ?? 0,
      chipPlan: _mapList(m['chipPlan'] as List? ?? const []).map(chipPlanEntryFromMap).toList(),
      rebuyStack: (m['rebuyStack'] as num?)?.toInt() ?? 0,
      rebuyChipPlan: _mapList(m['rebuyChipPlan'] as List? ?? const [])
          .map(chipPlanEntryFromMap)
          .toList(),
      addOnStack: (m['addOnStack'] as num?)?.toInt() ?? 0,
      addOnChipPlan: _mapList(m['addOnChipPlan'] as List? ?? const [])
          .map(chipPlanEntryFromMap)
          .toList(),
      levels: _mapList(m['levels'] as List? ?? const []).map(blindLevelFromMap).toList(),
      levelDuration: (m['levelDuration'] as num?)?.toInt() ?? 15,
      expectedFinishMins: (m['expectedFinishMins'] as num?)?.toInt() ?? 0,
      prizes: _mapList(m['prizes'] as List? ?? const []).map(prizeFromMap).toList(),
      prizePool: (m['prizePool'] as num?)?.toInt() ?? 0,
      organizerAmount: (m['organizerAmount'] as num?)?.toInt() ?? 0,
      colorUpInstructions:
          List<String>.from(m['colorUpInstructions'] as List? ?? const []),
      warnings: List<String>.from(m['warnings'] as List? ?? const []),
    );

// ─────────────────────────────────────────────────────────────────────────────
// GameSettings
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> gameSettingsToMap(GameSettings s) => {
      'name': s.name,
      'date': s.date,
      'time': s.time,
      'location': s.location,
      'players': s.players,
      'durationHours': s.durationHours,
      'buyIn': s.buyIn,
      'koEnabled': s.koEnabled,
      'koAmount': s.koAmount,
      'rebuys': s.rebuys,
      'rebuysCloseLevel': s.rebuysCloseLevel,
      'rebuyLimit': s.rebuyLimit,
      'reEntry': s.reEntry,
      'addOn': s.addOn,
      'addOnCloseLevel': s.addOnCloseLevel,
      'anteEnabled': s.anteEnabled,
      'anteAfterLevel': s.anteAfterLevel,
      'anteStyle': s.anteStyle.name,
      'antePreference': s.antePreference.name,
      'organizerPct': s.organizerPct,
      'chipSet': s.chipSet.map(chipColorToMap).toList(),
      'chipSetName': s.chipSetName,
      'announceEliminations': s.announceEliminations,
      'forcePaidPlaces': s.forcePaidPlaces,
      'rebuyCost': s.rebuyCost,
      'addOnCost': s.addOnCost,
      'locationPrivate': s.locationPrivate,
      'tableSettingsOverride': s.tableSettingsOverride == null
          ? null
          : tableSettingsToMap(s.tableSettingsOverride!),
    };

GameSettings gameSettingsFromMap(Map<String, dynamic> m) => GameSettings(
      name: (m['name'] as String?) ?? '',
      date: (m['date'] as String?) ?? '',
      time: (m['time'] as String?) ?? '',
      location: (m['location'] as String?) ?? '',
      players: (m['players'] as num?)?.toInt() ?? 2,
      durationHours: (m['durationHours'] as num?)?.toDouble() ?? 3,
      buyIn: (m['buyIn'] as num?)?.toInt() ?? 0,
      koEnabled: (m['koEnabled'] as bool?) ?? false,
      koAmount: (m['koAmount'] as num?)?.toInt() ?? 0,
      rebuys: (m['rebuys'] as bool?) ?? false,
      rebuysCloseLevel: (m['rebuysCloseLevel'] as num?)?.toInt() ?? 0,
      rebuyLimit: (m['rebuyLimit'] as num?)?.toInt(),
      reEntry: (m['reEntry'] as bool?) ?? false,
      addOn: (m['addOn'] as bool?) ?? false,
      addOnCloseLevel: (m['addOnCloseLevel'] as num?)?.toInt() ?? 6,
      anteEnabled: (m['anteEnabled'] as bool?) ?? false,
      anteAfterLevel: (m['anteAfterLevel'] as num?)?.toInt() ?? 0,
      anteStyle:
          _enumByName(AnteStyle.values, m['anteStyle'], AnteStyle.bigBlind),
      antePreference: _enumByName(
          AntePreference.values, m['antePreference'], AntePreference.recommend),
      organizerPct: (m['organizerPct'] as num?)?.toInt() ?? 0,
      chipSet: _mapList(m['chipSet'] as List? ?? const [])
          .map(chipColorFromMap)
          .toList(),
      chipSetName: (m['chipSetName'] as String?) ?? '',
      announceEliminations: (m['announceEliminations'] as bool?) ?? false,
      forcePaidPlaces: (m['forcePaidPlaces'] as num?)?.toInt(),
      rebuyCost: (m['rebuyCost'] as num?)?.toInt(),
      addOnCost: (m['addOnCost'] as num?)?.toInt(),
      locationPrivate: (m['locationPrivate'] as bool?) ?? false,
      tableSettingsOverride: m['tableSettingsOverride'] == null
          ? null
          : tableSettingsFromMap(
              Map<String, dynamic>.from(m['tableSettingsOverride'] as Map)),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Players / chat / slots / announcements / audit / polls
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> playerToMap(Player p) => {
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

Player playerFromMap(Map<String, dynamic> m) => Player(
      id: m['id'] as String,
      name: (m['name'] as String?) ?? '',
      isGuest: (m['isGuest'] as bool?) ?? false,
      inviterId: m['inviterId'] as String?,
      guestSlot: (m['guestSlot'] as num?)?.toInt(),
      rsvp: m['rsvp'] == null
          ? null
          : _enumByName(Rsvp.values, m['rsvp'], Rsvp.maybe),
      checkedIn: (m['checkedIn'] as bool?) ?? false,
      confirmed: (m['confirmed'] as bool?) ?? false,
      eliminated: (m['eliminated'] as bool?) ?? false,
      eliminationPos: (m['eliminationPos'] as num?)?.toInt(),
      rebuys: (m['rebuys'] as num?)?.toInt() ?? 0,
      reEntries: (m['reEntries'] as num?)?.toInt() ?? 0,
      hasAddOn: (m['hasAddOn'] as bool?) ?? false,
      knockouts: (m['knockouts'] as num?)?.toInt() ?? 0,
      table: (m['table'] as num?)?.toInt() ?? 0,
      seat: (m['seat'] as num?)?.toInt() ?? 0,
      active: (m['active'] as bool?) ?? true,
    );

Map<String, dynamic> chatMessageToMap(ChatMessage msg) => {
      'id': msg.id,
      'authorId': msg.authorId,
      'authorName': msg.authorName,
      'body': msg.body,
      'timestamp': msg.timestamp.toIso8601String(),
      'deleted': msg.deleted,
      'pinned': msg.pinned,
      'gameId': msg.gameId,
    };

ChatMessage chatMessageFromMap(Map<String, dynamic> m) => ChatMessage(
      id: m['id'] as String,
      authorId: (m['authorId'] as String?) ?? '',
      authorName: (m['authorName'] as String?) ?? '',
      body: (m['body'] as String?) ?? '',
      timestamp: _isoOrNull(m['timestamp']) ?? DateTime.now(),
      deleted: (m['deleted'] as bool?) ?? false,
      pinned: (m['pinned'] as bool?) ?? false,
      gameId: m['gameId'] as String?,
    );

Map<String, dynamic> guestSlotToMap(GuestSlot s) => {
      'id': s.id,
      'inviterId': s.inviterId,
      'slot': s.slot,
      'guestName': s.guestName,
      'status': s.status.name,
    };

GuestSlot guestSlotFromMap(Map<String, dynamic> m) => GuestSlot(
      id: m['id'] as String,
      inviterId: (m['inviterId'] as String?) ?? '',
      slot: (m['slot'] as num?)?.toInt() ?? 1,
      guestName: m['guestName'] as String?,
      status: _enumByName(
          GuestSlotStatus.values, m['status'], GuestSlotStatus.unclaimed),
    );

Map<String, dynamic> announcementToMap(Announcement a) => {
      'id': a.id,
      'text': a.text,
      'timestamp': a.timestamp.toIso8601String(),
    };

Announcement announcementFromMap(Map<String, dynamic> m) => Announcement(
      id: m['id'] as String,
      text: (m['text'] as String?) ?? '',
      timestamp: _isoOrNull(m['timestamp']) ?? DateTime.now(),
    );

Map<String, dynamic> auditRecordToMap(AuditRecord r) => {
      'id': r.id,
      'timestamp': r.timestamp.toIso8601String(),
      'type': r.type,
      'actor': r.actor,
      'details': r.details,
    };

AuditRecord auditRecordFromMap(Map<String, dynamic> m) => AuditRecord(
      id: m['id'] as String,
      timestamp: _isoOrNull(m['timestamp']) ?? DateTime.now(),
      type: (m['type'] as String?) ?? '',
      actor: (m['actor'] as String?) ?? '',
      details: (m['details'] as String?) ?? '',
    );

Map<String, dynamic> pollToMap(Poll p) => {
      'id': p.id,
      'question': p.question,
      'options': List<String>.from(p.options),
      'votes': {
        for (final e in p.votes.entries) e.key: List<String>.from(e.value),
      },
      'closed': p.closed,
      'createdAt': p.createdAt.toIso8601String(),
      'multi': p.multi,
    };

Poll pollFromMap(Map<String, dynamic> m) => Poll(
      id: m['id'] as String,
      question: (m['question'] as String?) ?? '',
      options: List<String>.from(m['options'] as List? ?? const []),
      votes: (m['votes'] as Map? ?? const {}).map(
        (k, v) => MapEntry(k as String, List<String>.from(v as List)),
      ),
      closed: (m['closed'] as bool?) ?? false,
      createdAt: _isoOrNull(m['createdAt']) ?? DateTime.now(),
      multi: (m['multi'] as bool?) ?? false,
    );

// ─────────────────────────────────────────────────────────────────────────────
// LiveGame
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> liveGameToMap(LiveGame game) {
  final announcements = game.announcements;
  final audit = game.auditHistory;
  return {
    'id': game.id,
    'groupId': game.groupId,
    'settings': gameSettingsToMap(game.settings),
    'structure': tournamentStructureToMap(game.structure),
    'status': game.status.name,
    'publicCode': game.publicCode,
    'tvCode': game.tvCode,
    'currentLevel': game.currentLevel,
    'timerRunning': game.timerRunning,
    'secondsRemaining': game.secondsRemaining,
    'players': game.players.map(playerToMap).toList(),
    'chat': game.chat.map(chatMessageToMap).toList(),
    'announcements': announcements.length > kMaxEncodedAnnouncements
        ? announcements
            .sublist(announcements.length - kMaxEncodedAnnouncements)
            .map(announcementToMap)
            .toList()
        : announcements.map(announcementToMap).toList(),
    'auditHistory': audit.length > kMaxEncodedAuditRecords
        ? audit.sublist(audit.length - kMaxEncodedAuditRecords)
              .map(auditRecordToMap)
              .toList()
        : audit.map(auditRecordToMap).toList(),
    'totalChipsInPlay': game.totalChipsInPlay,
    'pendingGuests': game.pendingGuests.map(playerToMap).toList(),
    'finishOrder': List<String>.from(game.finishOrder),
    'speedRecommendation': game.speedRecommendation?.name,
    'settlementConfirmed': game.settlementConfirmed,
    'seatingConfirmed': game.seatingConfirmed,
    'checkInClosed': game.checkInClosed,
    'structureConfirmed': game.structureConfirmed,
    'structureLockedAtT10': game.structureLockedAtT10,
    'dealerPlayerId': game.dealerPlayerId,
    'guestSlots': game.guestSlots.map(guestSlotToMap).toList(),
    'originalLevels': game.originalLevels?.map(blindLevelToMap).toList(),
    'rebuyRequests': List<String>.from(game.rebuyRequests),
    'addOnRequests': List<String>.from(game.addOnRequests),
    'levelEndTime': _nullOrIso(game.levelEndTime),
    'changeLog': List<String>.from(game.changeLog),
  };
}

LiveGame liveGameFromMap(Map<String, dynamic> map) => LiveGame(
      id: map['id'] as String,
      groupId: (map['groupId'] as String?) ?? '',
      settings:
          gameSettingsFromMap(Map<String, dynamic>.from(map['settings'] as Map)),
      structure: tournamentStructureFromMap(
          Map<String, dynamic>.from(map['structure'] as Map)),
      status: _enumByName(
          LiveGameStatus.values, map['status'], LiveGameStatus.draft),
      publicCode: (map['publicCode'] as String?) ?? '',
      tvCode: (map['tvCode'] as String?) ?? '',
      currentLevel: (map['currentLevel'] as num?)?.toInt() ?? 1,
      timerRunning: (map['timerRunning'] as bool?) ?? false,
      secondsRemaining: (map['secondsRemaining'] as num?)?.toInt() ?? 0,
      players: _mapList(map['players'] as List? ?? const [])
          .map(playerFromMap)
          .toList(),
      chat: _mapList(map['chat'] as List? ?? const [])
          .map(chatMessageFromMap)
          .toList(),
      announcements: _mapList(map['announcements'] as List? ?? const [])
          .map(announcementFromMap)
          .toList(),
      auditHistory: _mapList(map['auditHistory'] as List? ?? const [])
          .map(auditRecordFromMap)
          .toList(),
      totalChipsInPlay: (map['totalChipsInPlay'] as num?)?.toInt() ?? 0,
      pendingGuests: _mapList(map['pendingGuests'] as List? ?? const [])
          .map(playerFromMap)
          .toList(),
      finishOrder: List<String>.from(map['finishOrder'] as List? ?? const []),
      speedRecommendation: map['speedRecommendation'] == null
          ? null
          : _enumByName(SpeedRecommendation.values, map['speedRecommendation'],
              SpeedRecommendation.speedUp),
      settlementConfirmed: (map['settlementConfirmed'] as bool?) ?? false,
      seatingConfirmed: (map['seatingConfirmed'] as bool?) ?? false,
      checkInClosed: (map['checkInClosed'] as bool?) ?? false,
      structureConfirmed: (map['structureConfirmed'] as bool?) ?? false,
      structureLockedAtT10: (map['structureLockedAtT10'] as bool?) ?? false,
      dealerPlayerId: map['dealerPlayerId'] as String?,
      guestSlots: _mapList(map['guestSlots'] as List? ?? const [])
          .map(guestSlotFromMap)
          .toList(),
      originalLevels: (map['originalLevels'] as List?)
          ?.map((e) => blindLevelFromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      rebuyRequests:
          List<String>.from(map['rebuyRequests'] as List? ?? const []),
      addOnRequests: List<String>.from(map['addOnRequests'] as List? ?? const []),
      levelEndTime: _isoOrNull(map['levelEndTime']),
      changeLog:
          List<String>.from(map['changeLog'] as List? ?? const []),
    );

/// Firestore representation: list-like collections that benefit from targeted
/// per-element updates are stored as maps keyed by element id, each entry
/// carrying its original `orderIndex` so decode restores exact ordering.
Map<String, dynamic> liveGameToFirestoreDoc(LiveGame game) {
  final base = liveGameToMap(game);
  Map<String, dynamic> listToIdMap(String key) {
    final items = List<Map<String, dynamic>>.from(base[key] as List);
    return {
      for (var i = 0; i < items.length; i++)
        items[i]['id'] as String: {...items[i], 'orderIndex': i},
    };
  }

  return {
    ...base,
    'players': listToIdMap('players'),
    'pendingGuests': listToIdMap('pendingGuests'),
    'guestSlots': listToIdMap('guestSlots'),
  };
}

LiveGame liveGameFromFirestoreDoc(Map<String, dynamic> doc) {
  List<Map<String, dynamic>> idMapToList(Object? raw) {
    if (raw is Map) {
      final entries = <Map<String, dynamic>>[];
      raw.forEach((key, value) {
        final item = Map<String, dynamic>.from(value as Map);
        item.putIfAbsent('id', () => key as String);
        entries.add(item);
      });
      entries.sort((a, b) => ((a['orderIndex'] as num?) ?? 0)
          .compareTo((b['orderIndex'] as num?) ?? 0));
      return entries;
    }
    if (raw is List) return _mapList(raw);
    return const [];
  }

  final map = Map<String, dynamic>.of(doc);
  map['players'] = idMapToList(doc['players']);
  map['pendingGuests'] = idMapToList(doc['pendingGuests']);
  map['guestSlots'] = idMapToList(doc['guestSlots']);
  return liveGameFromMap(map);
}

// ─────────────────────────────────────────────────────────────────────────────
// Cash sessions
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> cashSessionSettingsToMap(CashSessionSettings s) => {
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

CashSessionSettings cashSessionSettingsFromMap(Map<String, dynamic> m) =>
    CashSessionSettings(
      name: (m['name'] as String?) ?? '',
      date: (m['date'] as String?) ?? '',
      location: (m['location'] as String?) ?? '',
      smallBlind: (m['smallBlind'] as num?)?.toDouble() ?? 0,
      bigBlind: (m['bigBlind'] as num?)?.toDouble() ?? 0,
      minBuyIn: (m['minBuyIn'] as num?)?.toDouble() ?? 0,
      maxBuyIn: (m['maxBuyIn'] as num?)?.toDouble() ?? 0,
      currency: (m['currency'] as String?) ?? '',
      maxPlayers: (m['maxPlayers'] as num?)?.toInt() ?? 10,
      rakePct: (m['rakePct'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> cashPlayerToMap(CashPlayer p) => {
      'id': p.id,
      'name': p.name,
      'stack': p.stack,
      'totalBuyIns': p.totalBuyIns,
      'buyInCount': p.buyInCount,
      'cashedOut': p.cashedOut,
    };

CashPlayer cashPlayerFromMap(Map<String, dynamic> m) => CashPlayer(
      id: m['id'] as String,
      name: (m['name'] as String?) ?? '',
      stack: (m['stack'] as num?)?.toDouble() ?? 0,
      totalBuyIns: (m['totalBuyIns'] as num?)?.toDouble() ?? 0,
      buyInCount: (m['buyInCount'] as num?)?.toInt() ?? 1,
      cashedOut: (m['cashedOut'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> cashSessionToMap(CashSession session) => {
      'id': session.id,
      'settings': cashSessionSettingsToMap(session.settings),
      'isCompleted': session.isCompleted,
      'startTime': session.startTime.toIso8601String(),
      'unresolvedNote': session.unresolvedNote,
      'players': session.players.map(cashPlayerToMap).toList(),
    };

CashSession cashSessionFromMap(Map<String, dynamic> m) => CashSession(
      id: m['id'] as String,
      settings: cashSessionSettingsFromMap(
          Map<String, dynamic>.from(m['settings'] as Map)),
      isCompleted: (m['isCompleted'] as bool?) ?? false,
      startTime: _isoOrNull(m['startTime']) ?? DateTime.now(),
      unresolvedNote: m['unresolvedNote'] as String?,
      players: _mapList(m['players'] as List? ?? const [])
          .map(cashPlayerFromMap)
          .toList(),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Presets / notifications / groups
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> tournamentPresetToMap(TournamentPreset p) => {
      'id': p.id,
      'name': p.name,
      'buyIn': p.buyIn,
      'koEnabled': p.koEnabled,
      'koAmount': p.koAmount,
      'rebuys': p.rebuys,
      'rebuysCloseLevel': p.rebuysCloseLevel,
      'rebuyLimit': p.rebuyLimit,
      'reEntry': p.reEntry,
      'addOn': p.addOn,
      'addOnCloseLevel': p.addOnCloseLevel,
      'durationHours': p.durationHours,
      'anteEnabled': p.anteEnabled,
      'anteAfterLevel': p.anteAfterLevel,
      'organizerPct': p.organizerPct,
      'chipSetName': p.chipSetName,
      'chipSet': p.chipSet.map(chipColorToMap).toList(),
      'rebuyCost': p.rebuyCost,
      'addOnCost': p.addOnCost,
    };

TournamentPreset tournamentPresetFromMap(Map<String, dynamic> m) =>
    TournamentPreset(
      id: m['id'] as String,
      name: (m['name'] as String?) ?? '',
      buyIn: (m['buyIn'] as num?)?.toInt() ?? 0,
      koEnabled: (m['koEnabled'] as bool?) ?? false,
      koAmount: (m['koAmount'] as num?)?.toInt() ?? 0,
      rebuys: (m['rebuys'] as bool?) ?? false,
      rebuysCloseLevel: (m['rebuysCloseLevel'] as num?)?.toInt() ?? 0,
      rebuyLimit: (m['rebuyLimit'] as num?)?.toInt(),
      reEntry: (m['reEntry'] as bool?) ?? false,
      addOn: (m['addOn'] as bool?) ?? false,
      addOnCloseLevel: (m['addOnCloseLevel'] as num?)?.toInt() ?? 6,
      durationHours: (m['durationHours'] as num?)?.toDouble() ?? 3,
      anteEnabled: (m['anteEnabled'] as bool?) ?? false,
      anteAfterLevel: (m['anteAfterLevel'] as num?)?.toInt() ?? 0,
      organizerPct: (m['organizerPct'] as num?)?.toInt() ?? 0,
      chipSetName: (m['chipSetName'] as String?) ?? '',
      chipSet: _mapList(m['chipSet'] as List? ?? const [])
          .map(chipColorFromMap)
          .toList(),
      rebuyCost: (m['rebuyCost'] as num?)?.toInt(),
      addOnCost: (m['addOnCost'] as num?)?.toInt(),
    );

Map<String, dynamic> appNotificationToMap(AppNotification n) => {
      'id': n.id,
      'title': n.title,
      'body': n.body,
      'type': n.type.name,
      'link': n.link,
      'read': n.read,
      'timestamp': n.timestamp.toIso8601String(),
    };

AppNotification appNotificationFromMap(Map<String, dynamic> m) =>
    AppNotification(
      id: m['id'] as String,
      title: (m['title'] as String?) ?? '',
      body: (m['body'] as String?) ?? '',
      type: _enumByName(
          NotificationType.values, m['type'], NotificationType.system),
      link: m['link'] as String?,
      read: (m['read'] as bool?) ?? false,
      timestamp: _isoOrNull(m['timestamp']) ?? DateTime.now(),
    );

Map<String, dynamic> groupToMap(Group g) => {
      'id': g.id,
      'name': g.name,
      'joinCode': g.joinCode,
      'ownerId': g.ownerId,
      'members': g.members.map(appUserToMap).toList(),
      'games': g.games.map(liveGameToMap).toList(),
      'chat': g.chat.map(chatMessageToMap).toList(),
      'polls': g.polls.map(pollToMap).toList(),
      'notifications': g.notifications.map(appNotificationToMap).toList(),
      'icon': g.icon,
      'pinned': g.pinned,
      'tableSettings': tableSettingsToMap(g.tableSettings),
    };

Group groupFromMap(Map<String, dynamic> m) => Group(
      id: m['id'] as String,
      name: (m['name'] as String?) ?? '',
      joinCode: (m['joinCode'] as String?) ?? '',
      ownerId: (m['ownerId'] as String?) ?? '',
      members: _mapList(m['members'] as List? ?? const [])
          .map(appUserFromMap)
          .toList(),
      games: _mapList(m['games'] as List? ?? const [])
          .map(liveGameFromMap)
          .toList(),
      chat: _mapList(m['chat'] as List? ?? const [])
          .map(chatMessageFromMap)
          .toList(),
      polls: _mapList(m['polls'] as List? ?? const []).map(pollFromMap).toList(),
      notifications: _mapList(m['notifications'] as List? ?? const [])
          .map(appNotificationFromMap)
          .toList(),
      icon: (m['icon'] as String?) ?? '♠️',
      pinned: (m['pinned'] as bool?) ?? false,
      tableSettings: m['tableSettings'] == null
          ? TableSettings.fallback
          : tableSettingsFromMap(
              Map<String, dynamic>.from(m['tableSettings'] as Map)),
    );
