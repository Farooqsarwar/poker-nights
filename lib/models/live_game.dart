import 'chip_color.dart';
import 'payment_record.dart';
import 'shot_clock.dart';
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
    this.rebuyCloseChosenByOrganizer = false,
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
    this.expectedPlayersOverride,
    this.lockedExpectedPlayers,
    this.breaks = const [],
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
  final bool rebuyCloseChosenByOrganizer;

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

  /// Breaks the organizer configured (specification section 8).
  ///
  /// Empty means OFF, which is exactly how every tournament created before
  /// breaks existed behaved. The engine places the default when the organizer
  /// turns breaks on without choosing a position.
  final List<ScheduledBreak> breaks;

  /// The expected count FROZEN for physical preparation (specification
  /// section 6).
  ///
  /// Section 6 distinguishes four things, and this is the one that was
  /// missing: Confirmed (raw RSVPs), Expected (the organizer's estimate),
  /// **Locked** (that estimate frozen), and Actual checked-in.
  ///
  /// The point is stated in the specification directly: "late RSVP changes do
  /// not silently reshuffle the locked preparation". Once the host has counted
  /// physical chips into stacks for 15 people, a 16th RSVP arriving must not
  /// quietly rebuild the structure underneath them — it surfaces as a notice
  /// instead.
  ///
  /// Null means not locked. The start CTA still uses actual checked-in.
  final int? lockedExpectedPlayers;

  /// Head-count the host is preparing for, when they have overridden the
  /// figure the app derives from RSVPs (Technical section 6.1: "Expected
  /// players: from RSVP **or admin override**").
  ///
  /// RSVPs undercount routinely — people turn up who never answered, and the
  /// host knows it. Without this the chip and blind plan is built for the
  /// people who replied, which is exactly the "15 said yes, prepare for 20"
  /// case the client raised. Null means "trust the RSVPs".
  final int? expectedPlayersOverride;

  /// Ceiling on the organizer allocation (specification §7 and §18:
  /// "0-20%").
  static const int maxOrganizerPct = 20;

  /// The percentage calculations should actually use.
  ///
  /// The stored [organizerPct] is left exactly as written -- clamping it in
  /// the constructor would retroactively rewrite games created under the old
  /// 0-100 rule, and a stored value must never change meaning underneath a
  /// host who already ran the night. This clamps at the point of USE instead,
  /// so no prize split can be computed against a figure the specification
  /// forbids, however the settings were constructed.
  ///
  /// The forms cap entry at 20 as well; this is the backstop for every other
  /// path -- a preset, a restored document, a direct provider call.
  int get effectiveOrganizerPct => organizerPct.clamp(0, maxOrganizerPct);

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
    bool? rebuyCloseChosenByOrganizer,
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
    int? expectedPlayersOverride,
    bool clearExpectedPlayersOverride = false,
    int? lockedExpectedPlayers,
    bool clearLockedExpectedPlayers = false,
    List<ScheduledBreak>? breaks,
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
      rebuyCloseChosenByOrganizer: rebuyCloseChosenByOrganizer ?? this.rebuyCloseChosenByOrganizer,
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
      expectedPlayersOverride: clearExpectedPlayersOverride
          ? null
          : (expectedPlayersOverride ?? this.expectedPlayersOverride),
      lockedExpectedPlayers: clearLockedExpectedPlayers
          ? null
          : (lockedExpectedPlayers ?? this.lockedExpectedPlayers),
      breaks: breaks ?? this.breaks,
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
  cancelled,

  /// A scheduled break is running (section 8; addendum section 5).
  ///
  /// Distinct from `paused` and from `rebuypause`: those are things a host
  /// does, this one is part of the generated structure and ends by itself.
  /// Added at the END of the enum so stored index positions do not shift, and
  /// `_enumByName` degrades an unknown value to a safe fallback for clients
  /// that predate it.
  onBreak;

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
      case LiveGameStatus.onBreak:
        return 'Break';
    }
  }

  bool get isActiveLive =>
      this == LiveGameStatus.running ||
      this == LiveGameStatus.paused ||
      this == LiveGameStatus.rebuypause ||
      this == LiveGameStatus.onBreak ||
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
    this.finalTableRedrawCompleted = false,
    this.dealerPlayerId,
    this.guestSlots = const [],
    this.originalLevels,
    this.rebuyRequests = const [],
    this.addOnRequests = const [],
    this.levelEndTime,
    this.startedAt,
    this.changeLog = const [],
    this.payments = const [],
    this.organizerIds = const [],
    this.shotClock,
    this.revision = 0,
    this.lastIdempotencyKey,
    this.editorDeviceId = '',
    this.editorClaimedAt,
    this.audioMasterDeviceId = '',
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

  /// The single device that may write this whole game document while it is
  /// live. The first admin device to open the game claims the role and
  /// persists it; other admin devices become read-only for game edits so two
  /// sessions can no longer clobber each other (last-write-wins save war).
  final String editorDeviceId;

  /// The last moment the claiming device wrote to the game. Used to detect a
  /// stale editor claim: if the holder has been silent longer than the claim
  /// window, another admin device may take over the role.
  final DateTime? editorClaimedAt;

  /// The single device that speaks voice announcements — the "Audio Master"
  /// (User Flow §7.4, Technical §13.2: "other devices remain silent").
  ///
  /// It lives on the GAME, not in per-device memory, because silence has to be
  /// agreed between devices: a phone cannot know the TV was chosen unless the
  /// choice is shared. Empty means nobody has chosen yet, in which case only
  /// the authority (admin editor) device speaks — never every open tab.
  final String audioMasterDeviceId;

  /// True once the admin closes door check-in. Further walk-ins are not added
  /// (spec §4.7).
  final bool checkInClosed;

  /// True once the admin has reviewed and confirmed the AI-generated
  /// structure (30-minute pre-start estimate).
  final bool structureConfirmed;

  /// True once the final table redraw has been triggered and completed (BR-020).
  final bool finalTableRedrawCompleted;

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

  /// Server-clock instant the tournament actually started (first Start press).
  ///
  /// Pace has to be measured against the WALL CLOCK, not against the sum of
  /// level durations. Level time alone cannot see a pause: the end-of-rebuy
  /// settlement break has no countdown of its own (User Flow section 4.13)
  /// and the engine budgets 15 minutes for it (11-031), so a half-hour
  /// settlement left the drift model reading on-target while the dashboard's
  /// own wall-clock finish window showed the evening slipping — the two
  /// indicators contradicting each other. Null for a legacy game or before
  /// the clock is first started, in which case callers fall back to summed
  /// level durations.
  final DateTime? startedAt;

  /// Human-readable audit of post-publication event edits (user-flow spec
  /// §10.4): "2026-08-24 14:05 · buy-in 15 → 20". Oldest first; the provider
  /// caps the list when appending. Rendered prominently on the event page.
  final List<String> changeLog;

  /// Monotonic revision counter bumped on every accepted administrator
  /// operational action (elimination, rebuy, add-on, level transition, etc.).
  /// Combined with [lastIdempotencyKey] this guards against double-applying a
  /// duplicate action after a browser retry or an offline-restore replay
  /// (technical §18.1).
  /// A soft shot clock, when one is running (§12).
  ///
  /// Null almost always — it exists for the handful of moments a night when
  /// somebody needs putting on the clock. Deliberately separate from
  /// [levelEndTime]: §12 requires it to be "independent of level timer", and a
  /// level must never end early because a player tanked.
  final ShotClock? shotClock;

  /// Users given operational control of THIS tournament (§3, §28).
  ///
  /// Tournament-scoped by design — §32 lists it as a decision that must not
  /// drift. An organizer runs the night: rebuys, add-ons, eliminations,
  /// seating, and the private financials OF THIS GAME. They get no group-level
  /// rights at all: no approving members, no editing group settings, no
  /// managing admins, and nothing whatsoever in any other tournament.
  ///
  /// It solves a real problem rather than a theoretical one. A host who is
  /// also playing is the bottleneck on every rebuy at their own table; this
  /// lets them hand the controls to somebody for one evening without handing
  /// over the group.
  ///
  /// Empty on every tournament created before the role existed, which reads
  /// correctly as "admin only".
  final List<String> organizerIds;

  /// Whether [userId] is running this tournament as an assigned organizer.
  bool isOrganizer(String? userId) =>
      userId != null && organizerIds.contains(userId);

  /// Simulated payments recorded against this tournament (QA section 12).
  ///
  /// No money moves and no provider is contacted. The ledger exists so the
  /// prize pool, the host's view of who has settled up and the audit trail all
  /// agree — the part that has to be right whether the money went through the
  /// app or across the table in cash.
  final List<PaymentRecord> payments;

  /// Whether [playerId] has a successful payment of [purpose] on file.
  ///
  /// Rebuys are deliberately excluded from this shortcut: a player may rebuy
  /// several times, so "have they paid for a rebuy" is not a yes/no question.
  bool hasPaid(String playerId, PaymentPurpose purpose) => payments.any(
        (p) =>
            p.playerId == playerId &&
            p.purpose == purpose &&
            p.status == PaymentStatus.paid,
      );

  /// Total collected through the app, by purpose. Only successful payments
  /// count — a failed or cancelled attempt contributes nothing.
  int collected(PaymentPurpose purpose) => payments
      .where((p) => p.purpose == purpose && p.status.countsTowardPool)
      .fold<int>(0, (a, p) => a + p.amount);

  /// Everything collected through the app.
  int get totalCollected => payments
      .where((p) => p.status.countsTowardPool)
      .fold<int>(0, (a, p) => a + p.amount);

  final int revision;

  /// The idempotency key of the most recently accepted administrator action.
  /// A replayed action carrying the same key is skipped — never applied twice.
  final String? lastIdempotencyKey;

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

  int currentSecondsRemaining([Duration offset = Duration.zero]) {
    if (!timerRunning || levelEndTime == null) return secondsRemaining;
    final serverNow = DateTime.now().add(offset);
    final diff = levelEndTime!.difference(serverNow).inSeconds;
    return diff > 0 ? diff : 0;
  }

  BlindLevel? get nextLevelData {
    if (currentLevel >= structure.levels.length) return null;
    return structure.levels[currentLevel];
  }

  /// True once no further rebuy may be recorded.
  ///
  /// The settlement break itself is NOT closed: User Flow section 4.13 and
  /// 12-056 require the admin to record "any final valid rebuy from a hand
  /// that began before the deadline", and that happens during the break. This
  /// used to flip the instant status reached `rebuypause`, so `grantRebuy`
  /// refused for exactly the window the spec reserves for it. The real gate is
  /// [settlementConfirmed] — once the host confirms settlement, registration
  /// is closed permanently.
  bool get rebuysClosed {
    if (!settings.rebuys) return true;
    if (settlementConfirmed) return true;
    if (status == LiveGameStatus.rebuypause) return false;
    if (status.index > LiveGameStatus.rebuypause.index) return true;
    return currentLevel > settings.rebuysCloseLevel;
  }

  /// True once NO NEW PLAYER may enter (User Flow section 4.13, Technical
  /// section 10.3: "Late registration closes permanently when the rebuy level
  /// ends").
  ///
  /// Deliberately distinct from [rebuysClosed]. The settlement break is a
  /// window where an already-eliminated player may still take the final rebuy
  /// from a hand that began before the deadline (12-056), but nobody new may
  /// join. Sharing one flag meant reopening the rebuy window would also have
  /// reopened the door.
  bool get registrationClosed =>
      status.index >= LiveGameStatus.rebuypause.index ||
      // The closing LEVEL applies whether or not rebuys are enabled.
      //
      // Gating this on `settings.rebuys` left a no-rebuy tournament with no
      // closing point at all: `rebuypause` is only ever set inside
      // `nextLevel`'s `shouldPauseRebuy` branch, which itself requires
      // rebuys, so the status never reaches it and walk-ins, guest claims and
      // check-ins stayed open at level 12 of a live game. Technical section
      // 10.3 closes late registration when the rebuy level ends regardless.
      (settings.rebuysCloseLevel > 0 &&
          currentLevel > settings.rebuysCloseLevel);


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
    List<PaymentRecord>? payments,
    List<String>? organizerIds,
    ShotClock? shotClock,
    bool clearShotClock = false,
    SpeedRecommendation? speedRecommendation,
    TournamentStructure? structure,
    bool? settlementConfirmed,
    bool? seatingConfirmed,
    bool? checkInClosed,
    bool? structureConfirmed,
    bool? finalTableRedrawCompleted,
    String? dealerPlayerId,
    List<GuestSlot>? guestSlots,
    List<BlindLevel>? originalLevels,
    List<String>? rebuyRequests,
    List<String>? addOnRequests,
    DateTime? levelEndTime,
    DateTime? startedAt,
    bool clearSpeedRecommendation = false,
    bool clearLevelEndTime = false,
    List<String>? changeLog,
    int? revision,
    String? lastIdempotencyKey,
    String? editorDeviceId,
    DateTime? editorClaimedAt,
    String? audioMasterDeviceId,
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
      payments: payments ?? this.payments,
      organizerIds: organizerIds ?? this.organizerIds,
      shotClock: clearShotClock ? null : (shotClock ?? this.shotClock),
      speedRecommendation: clearSpeedRecommendation
          ? null
          : speedRecommendation ?? this.speedRecommendation,
      settlementConfirmed: settlementConfirmed ?? this.settlementConfirmed,
      seatingConfirmed: seatingConfirmed ?? this.seatingConfirmed,
      checkInClosed: checkInClosed ?? this.checkInClosed,
      structureConfirmed: structureConfirmed ?? this.structureConfirmed,
      finalTableRedrawCompleted: finalTableRedrawCompleted ?? this.finalTableRedrawCompleted,
      dealerPlayerId: dealerPlayerId ?? this.dealerPlayerId,
      guestSlots: guestSlots ?? this.guestSlots,
      originalLevels: originalLevels ?? this.originalLevels,
      rebuyRequests: rebuyRequests ?? this.rebuyRequests,
      addOnRequests: addOnRequests ?? this.addOnRequests,
      levelEndTime: clearLevelEndTime
          ? null
          : levelEndTime ?? this.levelEndTime,
      startedAt: startedAt ?? this.startedAt,
      changeLog: changeLog ?? this.changeLog,
      revision: revision ?? this.revision,
      lastIdempotencyKey: lastIdempotencyKey ?? this.lastIdempotencyKey,
      editorDeviceId: editorDeviceId ?? this.editorDeviceId,
      editorClaimedAt: editorClaimedAt ?? this.editorClaimedAt,
      audioMasterDeviceId: audioMasterDeviceId ?? this.audioMasterDeviceId,
    );
  }
}
