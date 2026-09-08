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
    this.audience,
  });

  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final String? link;
  final bool read;
  final DateTime timestamp;

  /// Uids this notification is meant for. `null`/empty = broadcast to every
  /// group member. Used both by the inbox mirror (only matching devices copy
  /// the notification into their inbox) and by the OneSignal fan-out (only
  /// matching users receive the push).
  final List<String>? audience;

  /// Whether [uid] is an intended recipient of this notification.
  bool isFor(String uid) =>
      audience == null || audience!.isEmpty || audience!.contains(uid);

  AppNotification copyWith({String? id, bool? read, List<String>? audience}) {
    return AppNotification(
      id: id ?? this.id,
      title: title,
      body: body,
      type: type,
      link: link,
      read: read ?? this.read,
      timestamp: timestamp,
      audience: audience ?? this.audience,
    );
  }
}
