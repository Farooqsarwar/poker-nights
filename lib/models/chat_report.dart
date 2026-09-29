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
    this.reason,
  });

  /// The excerpt is a snapshot, so the host still sees what was said after the
  /// author edits or removes it.
  static const int maxExcerptLength = 200;

  static const int maxReasonLength = 120;

  /// §E10 (2) fixes the reasons a member can pick when they report -
  /// "Report (reason: offensive -> spam -> other)". A closed list, so the host
  /// reads the same three words whichever client filed the report.
  static const List<String> reasons = <String>['Offensive', 'Spam', 'Other'];

  final String id;
  final String messageId;
  final String authorId;
  final String authorName;
  final String reporterId;
  final String excerpt;
  final DateTime createdAt;

  /// Set when the message came from a game's chat rather than the group chat.
  final String? gameId;

  /// Why the reporter flagged the message, from [reasons].
  ///
  /// Nullable because every report filed before this field existed has no
  /// `reason` key at all: a legacy document has to keep decoding, and the host
  /// card has to render without one.
  final String? reason;

  static String idFor(String messageId, String reporterId) =>
      '${messageId}_$reporterId';

  /// Folds a caller-supplied reason onto [reasons]. Anything blank is no
  /// reason; anything unrecognised lands on the catch-all rather than
  /// widening the list a stored document can put in front of a host.
  static String? normalizeReason(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    for (final r in reasons) {
      if (r.toLowerCase() == value.toLowerCase()) return r;
    }
    return reasons.last;
  }

  Map<String, dynamic> toMap() => {
        'messageId': messageId,
        'authorId': authorId,
        'authorName': authorName,
        'reporterId': reporterId,
        'excerpt': excerpt.length > maxExcerptLength
            ? excerpt.substring(0, maxExcerptLength)
            : excerpt,
        if (gameId != null) 'gameId': gameId,
        if (reason != null) 'reason': reason,
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
        reason: _reasonFrom(m),
        createdAt: at,
      );

  /// Reads `reason` off a stored document. Absent, blank or non-textual all
  /// mean "this report predates the reason field" rather than an error - the
  /// field was added after reports were already being written.
  static String? _reasonFrom(Map<String, dynamic> m) {
    final raw = m['reason'];
    if (raw is! String) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;
    return value.length > maxReasonLength
        ? value.substring(0, maxReasonLength)
        : value;
  }
}
