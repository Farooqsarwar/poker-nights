enum NotificationType { game, invite, rsvp, chat, admin, result, system }

/// An in-app notification / alert.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.link,
    required this.read,
    required this.timestamp,
  });

  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final String? link;
  final bool read;
  final DateTime timestamp;

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      type: type,
      link: link,
      read: read ?? this.read,
      timestamp: timestamp,
    );
  }
}

