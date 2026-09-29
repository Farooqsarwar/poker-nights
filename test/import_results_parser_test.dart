import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/imported_night.dart';
import 'package:poker_night/utils/import_results_parser.dart';

void main() {
  group('ImportResultsParser.parse', () {
    test('parses a good line, winner first', () {
      final r = ImportResultsParser.parse(
        '2026-06-27; Costa, Alexey, Nina, Hugo, Elena',
      );
      expect(r.lines, hasLength(1));
      expect(r.lines.single.ok, isTrue);
      expect(r.lines.single.date, '2026-06-27');
      expect(r.lines.single.names, ['Costa', 'Alexey', 'Nina', 'Hugo', 'Elena']);
    });

    test('skips blank lines but keeps real line numbers', () {
      final r = ImportResultsParser.parse('\n2026-06-27; A, B\n\nnope\n');
      expect(r.lines.map((l) => l.lineNumber), [2, 4]);
      expect(r.failed.single.error, startsWith('Line 4:'));
    });

    test('exactly one semicolon', () {
      for (final bad in ['2026-06-27 A, B', '2026-06-27; A; B', ';;']) {
        final l = ImportResultsParser.parse(bad).lines.single;
        expect(l.ok, isFalse, reason: bad);
        expect(l.error, contains("write it as 'date; players in finishing order'"));
      }
    });

    test('date format and real calendar dates', () {
      for (final bad in ['27/06/2026', '2026-6-27', '2026-02-31', 'June 27', '']) {
        final l = ImportResultsParser.parse('$bad; A, B').lines.single;
        expect(l.ok, isFalse, reason: bad);
        expect(l.error, contains('YYYY-MM-DD'));
      }
      expect(ImportResultsParser.isValidDate('2024-02-29'), isTrue);
      expect(ImportResultsParser.isValidDate('2026-02-29'), isFalse);
    });

    test('at least two players', () {
      expect(ImportResultsParser.parse('2026-06-27; A').lines.single.ok, isFalse);
      expect(ImportResultsParser.parse('2026-06-27;').lines.single.ok, isFalse);
      expect(ImportResultsParser.parse('2026-06-27; A,, ,B,').lines.single.names,
          ['A', 'B']);
    });

    test('no player twice, ignoring case and spaces', () {
      final l = ImportResultsParser.parse('2026-06-27; Costa, Nina,  costa ')
          .lines
          .single;
      expect(l.ok, isFalse);
      expect(l.error, contains('twice'));
    });

    test('accents count as different names', () {
      final l = ImportResultsParser.parse('2026-06-27; Tomás, Tomas').lines.single;
      expect(l.ok, isTrue);
    });

    test('a date already in the season is refused', () {
      final r = ImportResultsParser.parse(
        '2026-06-27; A, B',
        takenDates: ['2026-06-27T19:00'],
      );
      expect(r.lines.single.ok, isFalse);
      expect(r.lines.single.error, contains('already in the season - skipped'));
    });

    test('a date repeated within the text is refused the second time', () {
      final r = ImportResultsParser.parse('2026-06-27; A, B\n2026-06-27; C, D');
      expect(r.lines[0].ok, isTrue);
      expect(r.lines[1].ok, isFalse);
      expect(r.lines[1].error, startsWith('Line 2:'));
    });

    test('valid lines import even when others fail', () {
      final r = ImportResultsParser.parse(
        '2026-06-20; A, B\nbroken\n2026-06-27; C, D\n2026-06-28; E',
      );
      expect(r.valid.map((l) => l.lineNumber), [1, 3]);
      expect(r.failed.map((l) => l.lineNumber), [2, 4]);
    });

    test('more than 30 players is refused', () {
      final names = List.generate(31, (i) => 'P$i').join(', ');
      expect(ImportResultsParser.parse('2026-06-27; $names').lines.single.ok, isFalse);
    });
  });

  group('ImportResultsParser matching', () {
    final index = ImportResultsParser.memberIndex([
      (id: 'u1', name: 'Costa'),
      (id: 'u2', name: 'Tomás'),
    ]);

    test('matches members by trimmed, lower-cased name', () {
      expect(ImportResultsParser.matchMember('  COSTA ', index), 'u1');
      expect(ImportResultsParser.matchMember('Nina', index), isNull);
    });

    test('accents count: Tomas is not Tomás', () {
      expect(ImportResultsParser.matchMember('tomás', index), 'u2');
      expect(ImportResultsParser.matchMember('Tomas', index), isNull);
    });

    test('toNight keeps order; unmatched names become guests as typed', () {
      final line = ImportResultsParser.parse('2026-06-27; costa, Nina , Tomas')
          .lines
          .single;
      final night = ImportResultsParser.toNight(line, index);
      expect(night.date, '2026-06-27');
      expect(night.id, ImportedNight.idForDate('2026-06-27'));
      expect(night.entries, const [
        ImportedEntry(playerId: 'u1'),
        ImportedEntry(guestName: 'Nina'),
        ImportedEntry(guestName: 'Tomas'),
      ]);
    });
  });

  group('ImportedNight', () {
    test('toMap / fromMap round trip', () {
      const night = ImportedNight(
        id: 'night-2026-06-27',
        date: '2026-06-27',
        entries: [ImportedEntry(playerId: 'u1'), ImportedEntry(guestName: 'Nina')],
      );
      final back = ImportedNight.fromMap(night.id, night.toMap());
      expect(back.date, night.date);
      expect(back.entries, night.entries);
      expect(night.toMap()['entries'], [
        {'playerId': 'u1'},
        {'guestName': 'Nina'},
      ]);
    });
  });
}
