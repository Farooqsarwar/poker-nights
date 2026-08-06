import 'chip_color.dart';
import 'game.dart';
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
    this.reEntry = false,
    required this.addOn,
    required this.anteEnabled,
    required this.anteAfterLevel,
    this.anteStyle = AnteStyle.bigBlind,
    required this.organizerPct,
    required this.chipSet,
    required this.chipSetName,
    this.announceEliminations = false,
    this.forcePaidPlaces,
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

  /// Re-entry is a separate, secondary option (checklist 09-030, §12.5).
  /// A re-entering player receives the approved entry stack and is recorded
  /// separately from rebuys (12-046/12-047).
  final bool reEntry;

  final bool addOn;
  final bool anteEnabled;
  final int anteAfterLevel;
  final AnteStyle anteStyle;
  final int organizerPct;
  final List<ChipColor> chipSet;
  final String chipSetName;

  /// Whether eliminated-player names are announced by voice (checklist
  /// 15-053). Optional per tournament and disabled by default.
  final bool announceEliminations;

  /// The manually overridden number of paid places (if not null).
  final int? forcePaidPlaces;

  GameSettings copyWith({
    String? name,
    bool? koEnabled,
    bool? anteEnabled,
    int? anteAfterLevel,
    AnteStyle? anteStyle,
    bool? announceEliminations,
    int? forcePaidPlaces,
  }) {
    return GameSettings(
      name: name ?? this.name,
      date: date,
      time: time,
      location: location,
      players: players,
      durationHours: durationHours,
      buyIn: buyIn,
      koEnabled: koEnabled ?? this.koEnabled,
      koAmount: koAmount,
      rebuys: rebuys,
      rebuysCloseLevel: rebuysCloseLevel,
      reEntry: reEntry,
      addOn: addOn,
      anteEnabled: anteEnabled ?? this.anteEnabled,
      anteAfterLevel: anteAfterLevel ?? this.anteAfterLevel,
      anteStyle: anteStyle ?? this.anteStyle,
      organizerPct: organizerPct,
      chipSet: chipSet,
      chipSetName: chipSetName,
      announceEliminations: announceEliminations ?? this.announceEliminations,
      forcePaidPlaces: forcePaidPlaces ?? this.forcePaidPlaces,
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
    this.dealerPlayerId,
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

  /// Randomly assigned initial dealer for the current seating (13-012,
  /// 13-026). The system does not track subsequent dealer-button rotation
  /// (13-032).
  final String? dealerPlayerId;

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

  int get confirmedCount =>
      players.where((p) => p.confirmed).length;

  BlindLevel? get currentLevelData {
    if (currentLevel < 1 || currentLevel > structure.levels.length) return null;
    return structure.levels[currentLevel - 1];
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

  LiveGame copyWith({
    String? id,
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
    String? dealerPlayerId,
  }) {
    return LiveGame(
      id: id ?? this.id,
      groupId: groupId,
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
      dealerPlayerId: dealerPlayerId ?? this.dealerPlayerId,
    );
  }
}
