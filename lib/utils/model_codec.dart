import '../models/app_notification.dart';
import '../models/cash_game.dart';
import '../models/chip_color.dart';
import '../models/game.dart';
import '../models/group.dart';
import '../models/live_game.dart';
import '../models/table_settings.dart';
import '../models/tournament.dart';
import '../models/tournament_format.dart';
import '../models/tournament_preset.dart';
import '../models/user.dart';
import '../models/payment_record.dart';
import '../models/shot_clock.dart';

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

T? _enumByNameOrNull<T extends Enum>(List<T> values, Object? raw) {
  if (raw is! String) return null;
  for (final v in values) {
    if (v.name == raw) return v;
  }
  return null;
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
      id: (m['id'] as String?) ?? '',
      name: (m['name'] as String?) ?? '',
      email: (m['email'] as String?) ?? '',
      isAdmin: (m['isAdmin'] as bool?) ?? false,
      stats: userStatsFromMap(Map<String, dynamic>.from((m['stats'] as Map?) ?? const {})),
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
      'manuallyEdited': l.manuallyEdited,
    };

BlindLevel blindLevelFromMap(Map<String, dynamic> m) => BlindLevel(
      level: (m['level'] as num?)?.toInt() ?? 1,
      sb: (m['sb'] as num?)?.toInt() ?? 0,
      bb: (m['bb'] as num?)?.toInt() ?? 0,
      ante: (m['ante'] as num?)?.toInt(),
      durationMins: (m['durationMins'] as num?)?.toInt() ?? 15,
      // Absent on every structure written before the marker existed, which is
      // correct: those levels were all engine-generated.
      manuallyEdited: (m['manuallyEdited'] as bool?) ?? false,
    );

Map<String, dynamic> paymentRecordToMap(PaymentRecord p) => {
      'id': p.id,
      'playerId': p.playerId,
      'purpose': p.purpose.name,
      'amount': p.amount,
      'status': p.status.name,
      'timestamp': p.timestamp.toIso8601String(),
      'idempotencyKey': p.idempotencyKey,
      'failureReason': p.failureReason,
    };

PaymentRecord paymentRecordFromMap(Map<String, dynamic> m) => PaymentRecord(
      id: (m['id'] as String?) ?? '',
      playerId: (m['playerId'] as String?) ?? '',
      purpose: _enumByName(
          PaymentPurpose.values, m['purpose'], PaymentPurpose.buyIn),
      amount: (m['amount'] as num?)?.toInt() ?? 0,
      status:
          _enumByName(PaymentStatus.values, m['status'], PaymentStatus.failed),
      timestamp:
          DateTime.tryParse((m['timestamp'] as String?) ?? '') ?? DateTime.now(),
      idempotencyKey: (m['idempotencyKey'] as String?) ?? '',
      failureReason: m['failureReason'] as String?,
    );

Map<String, dynamic> scheduledBreakToMap(ScheduledBreak b) => {
      'afterLevel': b.afterLevel,
      'durationMins': b.durationMins,
    };

ScheduledBreak scheduledBreakFromMap(Map<String, dynamic> m) => ScheduledBreak(
      afterLevel: (m['afterLevel'] as num?)?.toInt() ?? 0,
      durationMins: (m['durationMins'] as num?)?.toInt() ?? 10,
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
      'breaks': s.breaks.map(scheduledBreakToMap).toList(),
      'levelDuration': s.levelDuration,
      'plannedLevels': s.plannedLevels,
      'expectedFinishMins': s.expectedFinishMins,
      'prizes': s.prizes.map(prizeToMap).toList(),
      'prizePool': s.prizePool,
      'organizerAmount': s.organizerAmount,
      'roundingRemainder': s.roundingRemainder,
      'paidPlaces': s.paidPlaces,
      'colorUpInstructions': List<String>.from(s.colorUpInstructions),
      'warnings': List<String>.from(s.warnings),
      'styleNote': s.styleNote,
      'rebuysCloseLevel': s.rebuysCloseLevel,
      'engineVersion': s.engineVersion,
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
      breaks: _mapList(m['breaks'] as List? ?? const [])
          .map(scheduledBreakFromMap)
          .toList(),
      styleNote: (m['styleNote'] as String?) ?? '',
      rebuysCloseLevel: (m['rebuysCloseLevel'] as num?)?.toInt() ??
          (m['structureRebuysCloseLevel'] as num?)?.toInt() ?? 0,
      engineVersion: (m['engineVersion'] as String?) ?? '2.1.0',
      levelDuration: (m['levelDuration'] as num?)?.toInt() ?? 15,
      plannedLevels: (m['plannedLevels'] as num?)?.toInt() ?? 0,
      expectedFinishMins: (m['expectedFinishMins'] as num?)?.toInt() ?? 0,
      prizes: _mapList(m['prizes'] as List? ?? const []).map(prizeFromMap).toList(),
      prizePool: (m['prizePool'] as num?)?.toInt() ?? 0,
      organizerAmount: (m['organizerAmount'] as num?)?.toInt() ?? 0,
      roundingRemainder: (m['roundingRemainder'] as num?)?.toInt() ?? 0,
      paidPlaces: (m['paidPlaces'] as num?)?.toInt() ?? 0,
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
      'rebuyCloseChosenByOrganizer': s.rebuyCloseChosenByOrganizer,
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
      'expectedPlayersOverride': s.expectedPlayersOverride,
      'lockedExpectedPlayers': s.lockedExpectedPlayers,
      'breaks': s.breaks.map(scheduledBreakToMap).toList(),
      'expectedRebuys': s.expectedRebuys,
      'expectedReEntries': s.expectedReEntries,
      'expectedAddOns': s.expectedAddOns,
      'rebuyChips': s.rebuyChips,
      'reEntryChips': s.reEntryChips,
      'addOnChips': s.addOnChips,
      'levelDurationMins': s.levelDurationMins,
      'payoutShape': s.payoutShape.name,
      'format': s.format?.name,
      'maxReEntries': s.maxReEntries,
      'shootoutTables': s.shootoutTables,
      'shootoutTableTargetMins': s.shootoutTableTargetMins,
      'earlyArrivalBonusEnabled': s.earlyArrivalBonusEnabled,
      'earlyArrivalCutoffMins': s.earlyArrivalCutoffMins,
      'earlyArrivalBonusPctOverride': s.earlyArrivalBonusPctOverride,
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
      rebuyCloseChosenByOrganizer: (m['rebuyCloseChosenByOrganizer'] as bool?) ?? false,
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
      expectedPlayersOverride:
          (m['expectedPlayersOverride'] as num?)?.toInt(),
      // Absent on everything written before section 6's Locked concept
      // existed, which reads correctly as "not locked".
      lockedExpectedPlayers: (m['lockedExpectedPlayers'] as num?)?.toInt(),
      // Absent on everything written before section 8's breaks existed, and
      // an empty list reads correctly as "runs straight through".
      breaks: _mapList(m['breaks'] as List? ?? const [])
          .map(scheduledBreakFromMap)
          .toList(),
      // All absent on anything written before the host could override them,
      // and null is exactly "use the engine default" — so an old document
      // regenerates to the same structure it always did.
      expectedRebuys: (m['expectedRebuys'] as num?)?.toInt(),
      expectedReEntries: (m['expectedReEntries'] as num?)?.toInt(),
      expectedAddOns: (m['expectedAddOns'] as num?)?.toInt(),
      rebuyChips: (m['rebuyChips'] as num?)?.toInt(),
      reEntryChips: (m['reEntryChips'] as num?)?.toInt(),
      addOnChips: (m['addOnChips'] as num?)?.toInt(),
      levelDurationMins: (m['levelDurationMins'] as num?)?.toInt(),
      payoutShape: PayoutShape.values.firstWhere(
        (v) => v.name == m['payoutShape'],
        // Every tournament created before the selector existed stored no shape
        // at all, and every one of them was generated on the standard curve.
        orElse: () => PayoutShape.standard,
      ),
      format: _enumByNameOrNull(TournamentFormat.values, m['format']),
      maxReEntries: (m['maxReEntries'] as num?)?.toInt(),
      shootoutTables: (m['shootoutTables'] as num?)?.toInt(),
      shootoutTableTargetMins: (m['shootoutTableTargetMins'] as num?)?.toInt(),
      // Absent on every game written before the bonus existed, and those games
      // did not grant one — false is the honest default, not merely the safe.
      earlyArrivalBonusEnabled:
          (m['earlyArrivalBonusEnabled'] as bool?) ?? false,
      earlyArrivalCutoffMins: (m['earlyArrivalCutoffMins'] as num?)?.toInt(),
      earlyArrivalBonusPctOverride:
          (m['earlyArrivalBonusPctOverride'] as num?)?.toDouble(),
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
      'noShow': p.noShow,
      'confirmed': p.confirmed,
      'eliminated': p.eliminated,
      'eliminationPos': p.eliminationPos,
      'eliminatedAtLevel': p.eliminatedAtLevel,
      // §3 / §34a. Null on every game written so far — see the field's own doc
      // on [Player]. Persisted regardless so the day stack capture (§25.5)
      // lands, history written before it stays readable without a migration.
      'lowestStackBB': p.lowestStackBB,
      'rebuys': p.rebuys,
      'reEntries': p.reEntries,
      'hasAddOn': p.hasAddOn,
      'knockouts': p.knockouts,
      'table': p.table,
      'seat': p.seat,
      'active': p.active,
    };

Player playerFromMap(Map<String, dynamic> m) => Player(
      id: (m['id'] as String?) ?? '',
      name: (m['name'] as String?) ?? '',
      isGuest: (m['isGuest'] as bool?) ?? false,
      inviterId: m['inviterId'] as String?,
      guestSlot: (m['guestSlot'] as num?)?.toInt(),
      rsvp: m['rsvp'] == null
          ? null
          : _enumByName(Rsvp.values, m['rsvp'], Rsvp.maybe),
      checkedIn: (m['checkedIn'] as bool?) ?? false,
      noShow: (m['noShow'] as bool?) ?? false,
      confirmed: (m['confirmed'] as bool?) ?? false,
      eliminated: (m['eliminated'] as bool?) ?? false,
      eliminationPos: (m['eliminationPos'] as num?)?.toInt(),
      eliminatedAtLevel: (m['eliminatedAtLevel'] as num?)?.toInt(),
      lowestStackBB: (m['lowestStackBB'] as num?)?.toInt(),
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
      id: (m['id'] as String?) ?? '',
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
      id: (m['id'] as String?) ?? '',
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
      id: (m['id'] as String?) ?? '',
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
      id: (m['id'] as String?) ?? '',
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
      id: (m['id'] as String?) ?? '',
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
    'payments': game.payments.map(paymentRecordToMap).toList(),
    'organizerIds': List<String>.from(game.organizerIds),
    'shotClock': game.shotClock == null
        ? null
        : {
            'playerId': game.shotClock!.playerId,
            'endsAt': game.shotClock!.endsAt.toIso8601String(),
            'seconds': game.shotClock!.seconds,
          },
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
    'finalTableRedrawCompleted': game.finalTableRedrawCompleted,
    'dealerPlayerId': game.dealerPlayerId,
    'guestSlots': game.guestSlots.map(guestSlotToMap).toList(),
    'originalLevels': game.originalLevels?.map(blindLevelToMap).toList(),
    'rebuyRequests': List<String>.from(game.rebuyRequests),
    'addOnRequests': List<String>.from(game.addOnRequests),
    'levelEndTime': _nullOrIso(game.levelEndTime),
    'startedAt': _nullOrIso(game.startedAt),
    'actualDurationMins': game.actualDurationMins,
    'changeLog': List<String>.from(game.changeLog),
    'revision': game.revision,
    'lastIdempotencyKey': game.lastIdempotencyKey,
    'editorDeviceId': game.editorDeviceId,
    'editorClaimedAt': _nullOrIso(game.editorClaimedAt),
    'audioMasterDeviceId': game.audioMasterDeviceId,
  };
}

LiveGame liveGameFromMap(Map<String, dynamic> map) => LiveGame(
      id: (map['id'] as String?) ?? '',
      groupId: (map['groupId'] as String?) ?? '',
      settings:
          gameSettingsFromMap(Map<String, dynamic>.from(map['settings'] as Map)),
      payments: _mapList(map['payments'] as List? ?? const [])
          .map(paymentRecordFromMap)
          .toList(),
      // Absent on every tournament written before the role existed, which
      // reads correctly as "admin only".
      organizerIds:
          List<String>.from(map['organizerIds'] as List? ?? const []),
      shotClock: map['shotClock'] == null
          ? null
          : () {
              final sc = Map<String, dynamic>.from(map['shotClock'] as Map);
              final endsAt = DateTime.tryParse((sc['endsAt'] as String?) ?? '');
              if (endsAt == null) return null;
              return ShotClock(
                playerId: (sc['playerId'] as String?) ?? '',
                endsAt: endsAt,
                seconds: (sc['seconds'] as num?)?.toInt() ??
                    ShotClock.defaultSeconds,
              );
            }(),
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
      finalTableRedrawCompleted: (map['finalTableRedrawCompleted'] as bool?) ?? false,
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
      startedAt: _isoOrNull(map['startedAt']),
      actualDurationMins: (map['actualDurationMins'] as num?)?.toInt(),
      changeLog:
          List<String>.from(map['changeLog'] as List? ?? const []),
      revision: (map['revision'] as num?)?.toInt() ?? 0,
      lastIdempotencyKey: map['lastIdempotencyKey'] as String?,
      editorDeviceId: (map['editorDeviceId'] as String?) ?? '',
      editorClaimedAt: _isoOrNull(map['editorClaimedAt']),
      audioMasterDeviceId: (map['audioMasterDeviceId'] as String?) ?? '',
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
        ((items[i]['id'] as String?)?.isNotEmpty ?? false)
            ? items[i]['id'] as String
            : 'row-$i': {...items[i], 'orderIndex': i},
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
      'hasCashedOut': p.hasCashedOut,
    };

CashPlayer cashPlayerFromMap(Map<String, dynamic> m) => CashPlayer(
      id: (m['id'] as String?) ?? '',
      name: (m['name'] as String?) ?? '',
      stack: (m['stack'] as num?)?.toDouble() ?? 0,
      totalBuyIns: (m['totalBuyIns'] as num?)?.toDouble() ?? 0,
      buyInCount: (m['buyInCount'] as num?)?.toInt() ?? 1,
      cashedOut: (m['cashedOut'] as num?)?.toDouble() ?? 0,
      hasCashedOut: m.containsKey('hasCashedOut') 
          ? m['hasCashedOut'] as bool
          : ((m['cashedOut'] as num?)?.toDouble() ?? 0) > 0,
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
      id: (m['id'] as String?) ?? '',
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
      'breaks': p.breaks.map(scheduledBreakToMap).toList(),
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
      id: (m['id'] as String?) ?? '',
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
      breaks: _mapList(m['breaks'] as List? ?? const [])
          .map(scheduledBreakFromMap)
          .toList(),
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

/// Public [NotificationType] parser for callers outside this file (the
/// notification outbox stream in the repository).
NotificationType notificationTypeByName(Object? raw) =>
    _enumByName(NotificationType.values, raw, NotificationType.system);

Map<String, dynamic> appNotificationToMap(AppNotification n) => {
      'id': n.id,
      'title': n.title,
      'body': n.body,
      'type': n.type.name,
      'link': n.link,
      'read': n.read,
      'timestamp': n.timestamp.toIso8601String(),
      if (n.audience != null && n.audience!.isNotEmpty) 'audience': n.audience,
    };

AppNotification appNotificationFromMap(Map<String, dynamic> m) =>
    AppNotification(
      id: (m['id'] as String?) ?? '',
      title: (m['title'] as String?) ?? '',
      body: (m['body'] as String?) ?? '',
      type: _enumByName(
          NotificationType.values, m['type'], NotificationType.system),
      link: m['link'] as String?,
      read: (m['read'] as bool?) ?? false,
      timestamp: _isoOrNull(m['timestamp']) ?? DateTime.now(),
      audience: (m['audience'] as List?)?.map((e) => e.toString()).toList(),
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
      if (g.defaultChipSetId != null) 'defaultChipSetId': g.defaultChipSetId,
    };

Group groupFromMap(Map<String, dynamic> m) => Group(
      id: (m['id'] as String?) ?? '',
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
      defaultChipSetId: m['defaultChipSetId'] as String?,
    );
