/// Input sanitization helpers for user-generated content.
///
/// Spec §22: "Sanitize all chat, poll and name input."
class Sanitization {
  Sanitization._();

  /// Maximum length for chat messages (spec §14.1).
  static const int maxChatLength = 1000;

  /// Maximum length for player/guest names.
  static const int maxNameLength = 50;

  /// Maximum length for tournament names (spec §6.1).
  static const int maxTournamentNameLength = 80;

  /// Maximum length for tournament locations (spec §6.1).
  static const int maxLocationLength = 160;

  /// Maximum length for poll question.
  static const int maxPollQuestionLength = 200;

  /// Maximum length for poll option.
  static const int maxPollOptionLength = 100;

  /// Strips HTML tags and script content from user input.
  /// Returns a trimmed, safe plain-text string.
  static String sanitize(String input) {
    // Remove script/style blocks entirely
    var result = input.replaceAll(
      RegExp(r'<(script|style|iframe|object|embed)[^>]*>.*?</\1>',
          caseSensitive: false, dotAll: true),
      '',
    );
    // Strip remaining HTML tags
    result = result.replaceAll(RegExp(r'<[^>]*>'), '');
    // Decode common HTML entities
    result = result
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
    // Collapse multiple spaces
    result = result.replaceAll(RegExp(r'\s{2,}'), ' ');
    return result.trim();
  }

  /// Sanitize and enforce max length for chat messages.
  static String sanitizeChat(String input) =>
      sanitize(input).substring(0, _min(sanitize(input).length, maxChatLength));

  /// Sanitize and enforce max length for names.
  static String sanitizeName(String input) =>
      sanitize(input).substring(0, _min(sanitize(input).length, maxNameLength));

  /// Sanitize and enforce max length for poll question.
  static String sanitizePollQuestion(String input) =>
      sanitize(input)
          .substring(0, _min(sanitize(input).length, maxPollQuestionLength));

  /// Sanitize and enforce max length for poll option.
  static String sanitizePollOption(String input) =>
      sanitize(input)
          .substring(0, _min(sanitize(input).length, maxPollOptionLength));

  /// Sanitize and enforce max length for tournament name.
  static String sanitizeTournamentName(String input) =>
      sanitize(input)
          .substring(0, _min(sanitize(input).length, maxTournamentNameLength));

  /// Sanitize and enforce max length for tournament location.
  static String sanitizeLocation(String input) =>
      sanitize(input)
          .substring(0, _min(sanitize(input).length, maxLocationLength));

  static int _min(int a, int b) => a < b ? a : b;
}
