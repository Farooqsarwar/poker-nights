/// A member's report of a chat message (Addendum 1 - Apple guideline 1.2).
///
/// Lives at `groups/{gid}/reports/{messageId}_{reporterId}`: the deterministic
/// id makes reporting the same message twice a no-op instead of a pile of
/// duplicates. Only the group's admins can read or clear reports.
class ChatReport {
  const ChatReport({
    required this.id,
    required this.messageId,
    required this.authorId,
    required this.authorName,
    required this.reporterId,
    required this.excerpt,
    required this.createdAt,
    this.gameId,
  });

  /// The excerpt is a snapshot, so the host still sees what was said after the
  /// author edits or removes it.
  static const int maxExcerptLength = 200;

  final String id;
  final String messageId;
  final String authorId;
  final String authorName;
  final String reporterId;
  final String excerpt;
  final DateTime createdAt;

  /// Set when the message came from a game's chat rather than the group chat.
  final String? gameId;

  static String idFor(String messageId, String reporterId) =>
      '${messageId}_$reporterId';

  Map<String, dynamic> toMap() => {
        'messageId': messageId,
        'authorId': authorId,
        'authorName': authorName,
        'reporterId': reporterId,
        'excerpt': excerpt.length > maxExcerptLength
            ? excerpt.substring(0, maxExcerptLength)
            : excerpt,
        if (gameId != null) 'gameId': gameId,
      };

  static ChatReport fromMap(String id, Map<String, dynamic> m, DateTime at) =>
      ChatReport(
        id: id,
        messageId: (m['messageId'] as String?) ?? '',
        authorId: (m['authorId'] as String?) ?? '',
        authorName: (m['authorName'] as String?) ?? 'Member',
        reporterId: (m['reporterId'] as String?) ?? '',
        excerpt: (m['excerpt'] as String?) ?? '',
        gameId: m['gameId'] as String?,
        createdAt: at,
      );
}
