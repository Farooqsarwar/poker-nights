import 'app_notification.dart';
import 'game.dart';
import 'live_game.dart';
import 'table_settings.dart';
import 'user.dart';

/// A private poker club / group.
class Group {
  const Group({
    required this.id,
    required this.name,
    required this.joinCode,
    required this.ownerId,
    required this.members,
    required this.games,
    required this.chat,
    required this.polls,
    required this.notifications,
    this.icon = 'Spade',
    this.pinned = false,
    this.tableSettings = TableSettings.fallback,
    this.defaultChipSetId,
    this.learningOptOut = false,
  });

  final String id;
  final String name;
  final String joinCode;
  final String ownerId;
  final List<AppUser> members;
  final List<LiveGame> games;
  final List<ChatMessage> chat;
  final List<Poll> polls;
  final List<AppNotification> notifications;

  /// Icon name used as the group's icon in the sidebar and header.
  final String icon;

  /// When true the group floats to the top of the sidebar's group list.
  final bool pinned;

  /// Default table-capacity/randomization rules for every tournament this
  /// group runs, overridable per tournament on [GameSettings.tableSettingsOverride].
  final TableSettings tableSettings;

  /// Default chip set ID for games created in this group.
  final String? defaultChipSetId;

  /// Spec B9/H5: whether this group opts out of pace adaptation learning.
  final bool learningOptOut;

  List<LiveGame> get upcomingGames =>
      games.where((g) => g.status.isUpcoming).toList();

  List<LiveGame> get pastGames => games
      .where((g) =>
          g.status == LiveGameStatus.completed ||
          g.status == LiveGameStatus.cancelled)
      .toList();

  Group copyWith({
    String? name,
    String? joinCode,
    String? ownerId,
    List<AppUser>? members,
    List<LiveGame>? games,
    List<ChatMessage>? chat,
    List<Poll>? polls,
    List<AppNotification>? notifications,
    String? icon,
    bool? pinned,
    TableSettings? tableSettings,
    String? defaultChipSetId,
    bool clearDefaultChipSetId = false,
    bool? learningOptOut,
  }) {
    return Group(
      id: id,
      name: name ?? this.name,
      joinCode: joinCode ?? this.joinCode,
      ownerId: ownerId ?? this.ownerId,
      members: members ?? this.members,
      games: games ?? this.games,
      chat: chat ?? this.chat,
      polls: polls ?? this.polls,
      notifications: notifications ?? this.notifications,
      icon: icon ?? this.icon,
      pinned: pinned ?? this.pinned,
      tableSettings: tableSettings ?? this.tableSettings,
      // A null means "keep", so clearing the chip-set pointer needs its own
      // flag -- otherwise picking the Standard box on the chips screen would
      // silently keep the saved set it was meant to replace.
      defaultChipSetId: clearDefaultChipSetId
          ? null
          : defaultChipSetId ?? this.defaultChipSetId,
      learningOptOut: learningOptOut ?? this.learningOptOut,
    );
  }
}
