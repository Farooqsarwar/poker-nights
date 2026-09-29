import '../models/imported_night.dart';

/// One parsed line of the B12 "Import past results" text area.
class ImportLine {
  const ImportLine({
    required this.lineNumber,
    required this.raw,
    this.date,
    this.names = const [],
    this.error,
  });

  /// 1-based, counting blank lines, so it matches what the host sees.
  final int lineNumber;
  final String raw;

  /// `YYYY-MM-DD`; set once the date part validated.
  final String? date;

  /// Players in finishing order, winner first, as typed (trimmed).
  final List<String> names;

  /// Null when the line is good. Already names the line: "Line 3: ...".
  final String? error;

  bool get ok => error == null;
}

/// Result of [ImportResultsParser.parse].
class ImportParseResult {
  const ImportParseResult(this.lines);

  /// Every non-blank line, in order.
  final List<ImportLine> lines;

  List<ImportLine> get valid => [for (final l in lines) if (l.ok) l];
  List<ImportLine> get failed => [for (final l in lines) if (!l.ok) l];
}

/// Pure parsing and validation for Build Spec v3.1 §B12 (no Flutter imports).
///
/// One night per line: `2026-06-27; Costa, Alexey, Nina, Hugo, Elena`.
abstract final class ImportResultsParser {
  static const int minPlayers = 2;

  /// Matches the Firestore rule's `entries.size() <= 30`.
  static const int maxPlayers = 30;
  static const int maxNameLength = 40;

  /// Trim and lower-case. Accents are kept on purpose: "Tomás" != "Tomas".
  static String normalise(String name) => name.trim().toLowerCase();

  /// True for a real calendar date written exactly as `YYYY-MM-DD`.
  static bool isValidDate(String s) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return false;
    final d = DateTime.tryParse(s);
    if (d == null) return false;
    // DateTime rolls 2026-02-31 into March; a real date round-trips.
    return d.year == int.parse(s.substring(0, 4)) &&
        d.month == int.parse(s.substring(5, 7)) &&
        d.day == int.parse(s.substring(8, 10));
  }

  /// Parses and validates [text]. [takenDates] are the dates already in the
  /// season (played games and previously imported nights); a date repeated
  /// within [text] is refused the second time too. Valid lines stay valid
  /// even when others fail.
  static ImportParseResult parse(
    String text, {
    Iterable<String> takenDates = const [],
  }) {
    final taken = <String>{
      for (final d in takenDates)
        if (d.length >= 10) d.substring(0, 10),
    };
    final out = <ImportLine>[];
    final rows = text.split(RegExp(r'\r\n|\r|\n'));
    for (var i = 0; i < rows.length; i++) {
      final raw = rows[i];
      if (raw.trim().isEmpty) continue;
      final n = i + 1;
      String fail(String why) => 'Line $n: $why';
      ImportLine bad(String why) =>
          ImportLine(lineNumber: n, raw: raw, error: fail(why));

      final parts = raw.split(';');
      if (parts.length != 2) {
        out.add(bad("write it as 'date; players in finishing order'."));
        continue;
      }
      final date = parts[0].trim();
      if (!isValidDate(date)) {
        out.add(bad(
          date.isEmpty
              ? 'the date is missing - use YYYY-MM-DD.'
              : "'$date' is not a date - use YYYY-MM-DD.",
        ));
        continue;
      }
      final names = [
        for (final s in parts[1].split(','))
          if (s.trim().isNotEmpty) s.trim(),
      ];
      if (names.length < minPlayers) {
        out.add(bad('a night needs at least $minPlayers players.'));
        continue;
      }
      if (names.length > maxPlayers) {
        out.add(bad('at most $maxPlayers players per night.'));
        continue;
      }
      final long = names.where((s) => s.length > maxNameLength).firstOrNull;
      if (long != null) {
        out.add(bad("'$long' is too long for a name."));
        continue;
      }
      final seen = <String>{};
      String? twice;
      for (final s in names) {
        if (!seen.add(normalise(s))) {
          twice = s;
          break;
        }
      }
      if (twice != null) {
        out.add(bad("'$twice' appears twice."));
        continue;
      }
      if (taken.contains(date)) {
        out.add(bad('$date is already in the season - skipped.'));
        continue;
      }
      taken.add(date);
      out.add(ImportLine(lineNumber: n, raw: raw, date: date, names: names));
    }
    return ImportParseResult(out);
  }

  /// Index of members by normalised name, for [toNight]. The first member wins
  /// when two share a name.
  static Map<String, String> memberIndex(
    Iterable<({String id, String name})> members,
  ) {
    final index = <String, String>{};
    for (final m in members) {
      index.putIfAbsent(normalise(m.name), () => m.id);
    }
    return index;
  }

  /// The member id [name] matches, or null when it is a guest.
  static String? matchMember(String name, Map<String, String> memberIndex) =>
      memberIndex[normalise(name)];

  /// Turns a valid [line] into a stored night: names that match a member
  /// become `playerId`, the rest keep `guestName` exactly as typed.
  static ImportedNight toNight(
    ImportLine line,
    Map<String, String> memberIndex,
  ) {
    assert(line.ok && line.date != null);
    final date = line.date!;
    return ImportedNight(
      id: ImportedNight.idForDate(date),
      date: date,
      entries: [
        for (final name in line.names)
          if (matchMember(name, memberIndex) case final id?)
            ImportedEntry(playerId: id)
          else
            ImportedEntry(guestName: name),
      ],
    );
  }
}
