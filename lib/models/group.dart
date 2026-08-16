import 'app_notification.dart';
import 'game.dart';
import 'live_game.dart';
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
    this.icon = '♠️',
    this.pinned = false,
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

  /// Short emoji used as the group's icon in the sidebar and header.
  final String icon;

  /// When true the group floats to the top of the sidebar's group list.
  final bool pinned;

  List<LiveGame> get upcomingGames =>
      games.where((g) => g.status.isUpcoming).toList();

  List<LiveGame> get pastGames =>
      games.where((g) => g.status == LiveGameStatus.completed).toList();

  Group copyWith({
    String? name,
    String? joinCode,
    List<AppUser>? members,
    List<LiveGame>? games,
    List<ChatMessage>? chat,
    List<Poll>? polls,
    List<AppNotification>? notifications,
    String? icon,
    bool? pinned,
  }) {
    return Group(
      id: id,
      name: name ?? this.name,
      joinCode: joinCode ?? this.joinCode,
      ownerId: ownerId,
      members: members ?? this.members,
      games: games ?? this.games,
      chat: chat ?? this.chat,
      polls: polls ?? this.polls,
      notifications: notifications ?? this.notifications,
      icon: icon ?? this.icon,
      pinned: pinned ?? this.pinned,
    );
  }
}

