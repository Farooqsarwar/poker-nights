/// Input sanitization helpers for user-generated content.
///
/// Spec §22: "Sanitize all chat, poll and name input."
class Sanitization {
  Sanitization._();

  /// Maximum length for chat messages (spec §14.1).
  static const int maxChatLength = 1000;

  /// Maximum length for player/guest names.
  static const int maxNameLength = 40;

  /// Maximum length for tournament names (spec §6.1).
  static const int maxTournamentNameLength = 80;

  /// Maximum length for tournament locations (spec §6.1).
  static const int maxLocationLength = 160;

  /// Maximum length for poll question.
  static const int maxPollQuestionLength = 120;

  /// Maximum length for poll option.
  static const int maxPollOptionLength = 60;

  /// Unicode emoji rejection regex per Spec T141/A3 ("no emoji anywhere").
  static final RegExp emojiRegex = RegExp(
    r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}'
    r'\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{FE00}-\u{FE0F}\u{1F900}-\u{1F9FF}'
    r'\u{1F018}-\u{1F270}\u{2388}-\u{23E8}\u{200D}\u{1FA70}-\u{1FAFF}]',
    unicode: true,
  );

  /// True if [input] contains any Unicode emoji.
  static bool hasEmoji(String input) => emojiRegex.hasMatch(input);

  /// Strips Unicode emoji from [input].
  static String removeEmoji(String input) => input.replaceAll(emojiRegex, '');

  /// Strips HTML tags and script content from user input.
  /// Returns a trimmed, safe plain-text string.
  static String sanitize(String input) {
    // Decode common HTML entities first so that obfuscated tags (e.g. &lt;script&gt;) 
    // are exposed before stripping.
    var result = input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
        
    // Remove script/style blocks entirely
    result = result.replaceAll(
      RegExp(r'<(script|style|iframe|object|embed)[^>]*>.*?</\1>',
          caseSensitive: false, dotAll: true),
      '',
    );
    // Strip remaining HTML tags
    result = result.replaceAll(RegExp(r'<[^>]*>'), '');
    
    // Strip Unicode emojis per Spec T141/A3
    result = result.replaceAll(emojiRegex, '');

    // Collapse multiple spaces
    result = result.replaceAll(RegExp(r'\s{2,}'), ' ');
    return result.trim();
  }

  static String _truncate(String s, int maxLen) =>
      s.length <= maxLen ? s : s.substring(0, maxLen);

  /// Sanitize and enforce max length for chat messages.
  static String sanitizeChat(String input) =>
      _truncate(sanitize(input), maxChatLength);

  /// Sanitize and enforce max length for names.
  static String sanitizeName(String input) =>
      _truncate(sanitize(input), maxNameLength);

  /// Sanitize and enforce max length for poll question.
  static String sanitizePollQuestion(String input) =>
      _truncate(sanitize(input), maxPollQuestionLength);

  /// Sanitize and enforce max length for poll option.
  static String sanitizePollOption(String input) =>
      _truncate(sanitize(input), maxPollOptionLength);

  /// Sanitize and enforce max length for tournament name.
  static String sanitizeTournamentName(String input) =>
      _truncate(sanitize(input), maxTournamentNameLength);

  /// Sanitize and enforce max length for tournament location.
  static String sanitizeLocation(String input) =>
      _truncate(sanitize(input), maxLocationLength);
}
