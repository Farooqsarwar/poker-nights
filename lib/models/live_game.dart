import 'chip_color.dart';
import 'game.dart';
import 'table_settings.dart';
import 'tournament.dart';

/// Settings captured when creating a tournament game.
class GameSettings {
  const GameSettings({
    required this.name,
    required this.date,
    required this.time,
    required this.location,
    required this.players,
    required this.durationHours,
    required this.buyIn,
    required this.koEnabled,
    required this.koAmount,
    required this.rebuys,
    required this.rebuysCloseLevel,
    this.rebuyLimit,
    this.reEntry = false,
    required this.addOn,
    this.addOnCloseLevel = 6,
    required this.anteEnabled,
    required this.anteAfterLevel,
    this.anteStyle = AnteStyle.bigBlind,
    this.antePreference = AntePreference.recommend,
    required this.organizerPct,
    required this.chipSet,
    required this.chipSetName,
    this.announceEliminations = false,
    this.forcePaidPlaces,
    this.rebuyCost,
    this.addOnCost,
    this.locationPrivate = false,
    this.tableSettingsOverride,
  });

  final String name;
  final String date;
  final String time;
  final String location;
  final int players;
  final double durationHours;
  final int buyIn;
  final bool koEnabled;
  final int koAmount;
  final bool rebuys;
  final int rebuysCloseLevel;

  /// Number of rebuys allowed per player when rebuys are limited.
  final int? rebuyLimit;

  /// Re-entry is a separate, secondary option (checklist 09-030, §12.5).
  /// A re-entering player receives the approved entry stack and is recorded
  /// separately from rebuys (12-046/12-047).
  final bool reEntry;
  final bool addOn;

  /// Level after which add-ons are no longer available. Defaults to end of
  /// Level 6 (client feedback: "add-on moment, default end L6").
  final int addOnCloseLevel;

  final bool anteEnabled;
  final int anteAfterLevel;
  final AnteStyle anteStyle;

  /// The admin's ante choice made at creation (checklist 09-010).
  final AntePreference antePreference;

  final int organizerPct;
  final List<ChipColor> chipSet;
  final String chipSetName;

  /// Whether eliminated-player names are announced by voice (checklist
  /// 15-053). Optional per tournament and disabled by default.
  final bool announceEliminations;

  /// The manually overridden number of paid places (if not null).
  final int? forcePaidPlaces;

  /// Price charged for a single rebuy. Defaults to the buy-in when not set
  /// (checklist 09-050, 12-051).
  final int? rebuyCost;

  /// Price charged for the add-on. Defaults to the buy-in when not set
  /// (checklist 12-060).
  final int? addOnCost;

  /// When true, the address is hidden on the public/invite views and only
  /// shown to confirmed players shortly before the event (checklist 11-014,
  /// 11-015).
  final bool locationPrivate;

  /// Per-tournament override of the group's default table-capacity/
  /// randomization rules. Null means "use the group default"
  /// ([AppProvider.effectiveTableSettings] resolves this).
  final TableSettings? tableSettingsOverride;

  int get effectiveRebuyCost => rebuyCost ?? buyIn;
  int get effectiveAddOnCost => addOnCost ?? buyIn;

  GameSettings copyWith({
    String? name,
    String? date,
    String? time,
    String? location,
    int? players,
    double? durationHours,
    int? buyIn,
    bool? koEnabled,
    int? koAmount,
    bool? rebuys,
    int? rebuysCloseLevel,
    int? rebuyLimit,
    bool? reEntry,
    bool? addOn,
    int? addOnCloseLevel,
    bool? anteEnabled,
    int? anteAfterLevel,
    AnteStyle? anteStyle,
    AntePreference? antePreference,
    int? organizerPct,
    List<ChipColor>? chipSet,
    String? chipSetName,
    bool? announceEliminations,
    int? forcePaidPlaces,
    int? rebuyCost,
    int? addOnCost,
    bool? locationPrivate,
    TableSettings? tableSettingsOverride,
    bool clearTableSettingsOverride = false,
  }) {
    return GameSettings(
      name: name ?? this.name,
      date: date ?? this.date,
      time: time ?? this.time,
      location: location ?? this.location,
      players: players ?? this.players,
      durationHours: durationHours ?? this.durationHours,
      buyIn: buyIn ?? this.buyIn,
      koEnabled: koEnabled ?? this.koEnabled,
      koAmount: koAmount ?? this.koAmount,
      rebuys: rebuys ?? this.rebuys,
      rebuysCloseLevel: rebuysCloseLevel ?? this.rebuysCloseLevel,
      rebuyLimit: rebuyLimit ?? this.rebuyLimit,
      reEntry: reEntry ?? this.reEntry,
      addOn: addOn ?? this.addOn,
      addOnCloseLevel: addOnCloseLevel ?? this.addOnCloseLevel,
      anteEnabled: anteEnabled ?? this.anteEnabled,
      anteAfterLevel: anteAfterLevel ?? this.anteAfterLevel,
      anteStyle: anteStyle ?? this.anteStyle,
      antePreference: antePreference ?? this.antePreference,
      organizerPct: organizerPct ?? this.organizerPct,
      chipSet: chipSet ?? this.chipSet,
      chipSetName: chipSetName ?? this.chipSetName,
      announceEliminations: announceEliminations ?? this.announceEliminations,
      forcePaidPlaces: forcePaidPlaces ?? this.forcePaidPlaces,
      rebuyCost: rebuyCost ?? this.rebuyCost,
      addOnCost: addOnCost ?? this.addOnCost,
      locationPrivate: locationPrivate ?? this.locationPrivate,
      tableSettingsOverride: clearTableSettingsOverride
          ? null
          : (tableSettingsOverride ?? this.tableSettingsOverride),
    );
  }

  /// The scheduled start parsed from the configured date/time fields.
  DateTime? get scheduledStart => DateTime.tryParse('${date}T$time');

  /// RSVPs can be changed until one hour before the scheduled start
  /// (checklist 07-011/07-012, UAT-025). After this cutoff changes are closed.
  DateTime? get rsvpDeadline =>
      scheduledStart?.subtract(const Duration(hours: 1));

  bool get rsvpCutoffPassed =>
      rsvpDeadline != null && rsvpDeadline!.isBefore(DateTime.now());
}

/// Lifecycle status of a tournament.
enum LiveGameStatus {
  draft,
  published,
  checkin,
  ready,
  running,
  paused,
  rebuypause,
  finaltable,
  completed,
  cancelled;

  String get label {
    switch (this) {
      case LiveGameStatus.draft:
        return 'Draft';
      case LiveGameStatus.published:
        return 'Open for RSVP';
      case LiveGameStatus.checkin:
        return 'Check-in open';
      case LiveGameStatus.ready:
        return 'Ready to Start';
      case LiveGameStatus.running:
        return 'Live';
      case LiveGameStatus.paused:
        return 'Paused';
      case LiveGameStatus.rebuypause:
        return 'Break';
      case LiveGameStatus.finaltable:
        return 'Final Table';
      case LiveGameStatus.completed:
        return 'Completed';
      case LiveGameStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isActiveLive =>
      this == LiveGameStatus.running ||
      this == LiveGameStatus.paused ||
      this == LiveGameStatus.rebuypause ||
      this == LiveGameStatus.finaltable;

  bool get isUpcoming =>
      this != LiveGameStatus.completed && this != LiveGameStatus.cancelled;
}

enum SpeedRecommendation { speedUp, slowDown }

/// A full tournament game (live or past).
class LiveGame {
  const LiveGame({
    required this.id,
    required this.groupId,
    required this.settings,
    required this.structure,
    required this.status,
    required this.publicCode,
    required this.tvCode,
    required this.currentLevel,
    required this.timerRunning,
    required this.secondsRemaining,
    required this.players,
    required this.chat,
    required this.announcements,
    this.auditHistory = const [],
    required this.totalChipsInPlay,
    required this.pendingGuests,
    required this.finishOrder,
    this.speedRecommendation,
    this.settlementConfirmed = false,
    this.seatingConfirmed = false,
    this.checkInClosed = false,
    this.structureConfirmed = false,
    this.dealerPlayerId,
    this.guestSlots = const [],
    this.originalLevels,
    this.rebuyRequests = const [],
    this.addOnRequests = const [],
    this.levelEndTime,
    this.changeLog = const [],
  });

  final String id;
  final String groupId;
  final GameSettings settings;
  final TournamentStructure structure;
  final LiveGameStatus status;
  final String publicCode;
  final String tvCode;
  final int currentLevel;
  final bool timerRunning;
  final int secondsRemaining;
  final List<Player> players;
  final List<ChatMessage> chat;
  final List<Announcement> announcements;
  final List<AuditRecord> auditHistory;
  final int totalChipsInPlay;
  final List<Player> pendingGuests;
  final List<String> finishOrder; // playerIds, first-out first
  final SpeedRecommendation? speedRecommendation;

  /// True once the end-of-rebuy settlement has been confirmed. The public
  /// label then changes from "Estimated Prize Pool" to "Prize Pool"
  /// (checklist 12-068, 14-038/14-039, 15-009, 15-030).
  final bool settlementConfirmed;

  /// True once the admin has confirmed the generated physical seating before
  /// play starts (checklist 13-013). Seating changes clear it again.
  final bool seatingConfirmed;

  /// True once the admin closes door check-in. Further walk-ins are not added
  /// (spec §4.7).
  final bool checkInClosed;

  /// True once the admin has reviewed and confirmed the AI-generated
  /// structure (30-minute pre-start estimate).
  final bool structureConfirmed;

  /// True once the firm, one-time structure recalculation at T-minus-10-
  /// minutes (using the final "Going" headcount) has run. Set once by
  /// [AppProvider]'s ticker and never cleared, so the firm lock only fires
  /// a single time per tournament regardless of how long the app stays open.

  /// Randomly assigned initial dealer for the current seating (13-012,
  /// 13-026). The system does not track subsequent dealer-button rotation
  /// (13-032).
  final String? dealerPlayerId;

  /// Persisted named guest seats for the event. Kept in sync with "Going +N"
  /// RSVPs so unclaimed guest slots survive re-entry into the invite flow
  /// (checklist 07-014).
  final List<GuestSlot> guestSlots;

  /// Player ids that have requested a rebuy from the live player view. The
  /// admin grants them from the dashboard; granting clears the request.
  final List<String> rebuyRequests;

  /// Player ids that have requested an add-on from the live player view.
  final List<String> addOnRequests;

  /// The exact timestamp when the current timer will hit 0. Null if paused or stopped.
  final DateTime? levelEndTime;

  /// Human-readable audit of post-publication event edits (user-flow spec
  /// §10.4): "2026-08-24 14:05 · buy-in 15 → 20". Oldest first; the provider
  /// caps the list when appending. Rendered prominently on the event page.
  final List<String> changeLog;

  List<GuestSlot> get availableGuestSlots =>
      guestSlots.where((s) => s.available).toList();

  /// Number of roster members who have not RSVP'd yet (checklist 04-023/04-024).
  int get noResponseCount =>
      players.where((p) => !p.isGuest && p.rsvp == null).length;

  /// Snapshot of the blind levels as published. Compared against the live
  /// levels to show what the admin has changed since going live (§12.4 diff).
  final List<BlindLevel>? originalLevels;

  /// Level numbers whose blinds/ante/duration differ from the published
  /// snapshot — empty before the game is published or when nothing changed.
  List<int> get modifiedLevels {
    final orig = originalLevels;
    if (orig == null) return const [];
    final byLevel = {for (final l in orig) l.level: l};
    final changed = <int>[];
    for (final l in structure.levels) {
      final o = byLevel[l.level];
      if (o == null) continue;
      if (o.sb != l.sb ||
          o.bb != l.bb ||
          o.ante != l.ante ||
          o.durationMins != l.durationMins) {
        changed.add(l.level);
      }
    }
    return changed;
  }

  /// Public prize-pool label: estimated until settlement is confirmed.
  String get prizePoolLabel =>
      settlementConfirmed ? 'Prize Pool' : 'Estimated Prize Pool';

  Player? get dealerPlayer => dealerPlayerId == null
      ? null
      : players.where((p) => p.id == dealerPlayerId).firstOrNull;

  List<Player> get activePlayers =>
      players.where((p) => p.active && !p.eliminated).toList();

  List<Player> get eliminatedPlayers =>
      players.where((p) => p.eliminated).toList();

  int get goingCount =>
      players.where((p) => p.rsvp != null && p.rsvp!.isGoing).length;

  /// Members marked going, counting each one *plus* the guests their "Going +N"
  /// response brings — the headcount shown next to the invite in chat.
  int get goingWithGuestsCount => players
      .where((p) => !p.isGuest && (p.rsvp?.isGoing ?? false))
      .fold(0, (sum, p) => sum + 1 + p.rsvp!.guestCount);

  int get confirmedCount => players.where((p) => p.confirmed).length;

  BlindLevel? get currentLevelData {
    if (currentLevel < 1 || currentLevel > structure.levels.length) return null;
    return structure.levels[currentLevel - 1];
  }

  int get currentSecondsRemaining {
    if (!timerRunning || levelEndTime == null) return secondsRemaining;
    final diff = levelEndTime!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  BlindLevel? get nextLevelData {
    if (currentLevel >= structure.levels.length) return null;
    return structure.levels[currentLevel];
  }

  bool get rebuysClosed {
    if (!settings.rebuys) return true;
    if (status.index > LiveGameStatus.rebuypause.index) return true;
    if (status == LiveGameStatus.rebuypause) return false;
    return currentLevel > settings.rebuysCloseLevel;
  }


  /// Starting stacks are frozen the moment the tournament goes live. Blinds,
  /// levels and the player count stay editable during play (client feedback).
  bool get stacksLocked =>
      status == LiveGameStatus.running ||
      status == LiveGameStatus.paused ||
      status == LiveGameStatus.rebuypause ||
      status == LiveGameStatus.finaltable;

  LiveGame copyWith({
    String? id,
    String? groupId,
    GameSettings? settings,
    LiveGameStatus? status,
    String? publicCode,
    String? tvCode,
    int? currentLevel,
    bool? timerRunning,
    int? secondsRemaining,
    List<Player>? players,
    List<ChatMessage>? chat,
    List<Announcement>? announcements,
    List<AuditRecord>? auditHistory,
    int? totalChipsInPlay,
    List<Player>? pendingGuests,
    List<String>? finishOrder,
    SpeedRecommendation? speedRecommendation,
    TournamentStructure? structure,
    bool? settlementConfirmed,
    bool? seatingConfirmed,
    bool? checkInClosed,
    bool? structureConfirmed,
    String? dealerPlayerId,
    List<GuestSlot>? guestSlots,
    List<BlindLevel>? originalLevels,
    List<String>? rebuyRequests,
    List<String>? addOnRequests,
    DateTime? levelEndTime,
    List<String>? changeLog,
  }) {
    return LiveGame(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      settings: settings ?? this.settings,
      structure: structure ?? this.structure,
      status: status ?? this.status,
      publicCode: publicCode ?? this.publicCode,
      tvCode: tvCode ?? this.tvCode,
      currentLevel: currentLevel ?? this.currentLevel,
      timerRunning: timerRunning ?? this.timerRunning,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      players: players ?? this.players,
      chat: chat ?? this.chat,
      announcements: announcements ?? this.announcements,
      auditHistory: auditHistory ?? this.auditHistory,
      totalChipsInPlay: totalChipsInPlay ?? this.totalChipsInPlay,
      pendingGuests: pendingGuests ?? this.pendingGuests,
      finishOrder: finishOrder ?? this.finishOrder,
      speedRecommendation: speedRecommendation ?? this.speedRecommendation,
      settlementConfirmed: settlementConfirmed ?? this.settlementConfirmed,
      seatingConfirmed: seatingConfirmed ?? this.seatingConfirmed,
      checkInClosed: checkInClosed ?? this.checkInClosed,
      structureConfirmed: structureConfirmed ?? this.structureConfirmed,
      dealerPlayerId: dealerPlayerId ?? this.dealerPlayerId,
      guestSlots: guestSlots ?? this.guestSlots,
      originalLevels: originalLevels ?? this.originalLevels,
      rebuyRequests: rebuyRequests ?? this.rebuyRequests,
      addOnRequests: addOnRequests ?? this.addOnRequests,
      levelEndTime: levelEndTime ?? this.levelEndTime,
      changeLog: changeLog ?? this.changeLog,
    );
  }
}
