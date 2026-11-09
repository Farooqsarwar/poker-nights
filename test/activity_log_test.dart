import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Specification 2026-09 sections 14 and 29:
///
///   "Every live operational action should create a timestamped Tournament
///    Event / Activity Log record."
///   "Every operational action timestamped." (acceptance gate)
///
/// This is a source-level check rather than a behavioural one on purpose.
/// Driving these through the real provider needs Firebase, auth and a live
/// game, which makes the test slow and flaky for what is really a structural
/// guarantee: the method exists and it logs. A regression here is somebody
/// adding a new live action and forgetting the record — exactly what this
/// catches, and exactly what a mocked behavioural test would miss when the new
/// method simply isn't in the mock's script.
///
/// Five of these had no record at all when the audit was run: rebuy, add-on,
/// elimination, late player and seating. Money entered the game and the prize
/// pool moved with nothing written down.
void main() {
  /// Extracts one method body by brace-matching from its signature.
  String methodBody(String source, String signature) {
    final start = source.indexOf(signature);
    expect(
      start,
      isNot(-1),
      reason:
          'method "$signature" no longer exists — if it was renamed, update '
          'this test rather than deleting the requirement',
    );
    // Skip the parameter list before looking for the body. A signature like
    // `grantRebuy(String id, {String? idempotencyKey})` opens a brace for its
    // NAMED PARAMETERS, and matching from there ends at the parameter list
    // rather than the method — which made this test report methods as
    // unlogged when they were fine.
    final paren = source.indexOf('(', start);
    var parenDepth = 0;
    var afterParams = -1;
    for (var i = paren; i < source.length; i++) {
      if (source[i] == '(') parenDepth++;
      if (source[i] == ')') {
        parenDepth--;
        if (parenDepth == 0) {
          afterParams = i;
          break;
        }
      }
    }
    expect(afterParams, isNot(-1), reason: 'unbalanced parameter list');

    final open = source.indexOf('{', afterParams);
    var depth = 0;
    for (var i = open; i < source.length; i++) {
      if (source[i] == '{') depth++;
      if (source[i] == '}') {
        depth--;
        if (depth == 0) return source.substring(open, i + 1);
      }
    }
    fail('could not find the end of "$signature"');
  }

  String read(String path) => File(path).readAsStringSync();

  group('section 14 — every live operational action is logged', () {
    final actions = <({String file, String signature, String action})>[
      (
        file: 'lib/providers/app_provider_players.dart',
        signature: 'void grantRebuy(',
        action: 'Rebuy / re-entry',
      ),
      (
        file: 'lib/providers/app_provider_players.dart',
        signature: 'void grantAddOn(',
        action: 'Add-on',
      ),
      (
        file: 'lib/providers/app_provider_players.dart',
        signature: 'void eliminatePlayer(',
        action: 'Elimination',
      ),
      (
        file: 'lib/providers/app_provider_players.dart',
        signature: 'void generateSeating(',
        action: 'Generate seat',
      ),
      (
        file: 'lib/providers/app_provider_tournament.dart',
        signature: 'void addLatePlayer(',
        action: 'Late player',
      ),
    ];

    for (final a in actions) {
      test('${a.action} writes an activity-log record', () {
        final body = methodBody(read(a.file), a.signature);
        expect(
          body.contains('addAuditRecord('),
          isTrue,
          reason:
              '${a.action} is listed in specification section 14 as a live '
              'operational action, so it must create a timestamped record. '
              'An announcement is not a log entry — announcements are '
              'ephemeral and section 29 requires the action be reconstructable '
              'afterwards.',
        );
      });
    }
  });

  group('section 32 — the organizer cut is never called a rake', () {
    test('no user-facing string says "rake"', () {
      // `CashGame.rakePct` survives as a serialization field and is documented
      // as unused; schema is additive-only, so it stays. What must never
      // appear is the word in anything a user reads.
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (!line.toLowerCase().contains('rake')) continue;
          // Comments and the legacy field/key are permitted.
          final trimmed = line.trimLeft();
          if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
          if (line.contains('rakePct')) continue;
          offenders.add('${entity.path}:${i + 1}: ${line.trim()}');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'specification section 32 lists this as a term that must not '
            'drift:\n${offenders.join('\n')}',
      );
    });
  });
}
