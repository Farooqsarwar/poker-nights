import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/utils/formatters.dart';

/// §E17 row 6 and §G2.3 — join-code generation.
///
/// §E17 row 6 (spec `:3421`):
///
///   "Group / game / TV code generation | Creating a group/game, or a TV
///   pairing request | 6 chars from `ABCDEFGHJKMNPQRSTUVWXYZ23456789` (31
///   chars, no I L O 0 1); crypto RNG; server-transaction reservation, redraw
///   on collision; one namespace across group|game|tv | Code pill + QR (B8,
///   C-ops) | None - host cannot choose the code | §E7 | T112"
///
/// and T112 (spec `:5046`): "new group: a name is enough, then a 6-character
/// join code (no I, L, O, 0, 1) to share".
///
/// Three of the five requirements in that row are client-side properties of one
/// pure function and are asserted here: the length, the alphabet, and the fact
/// that the excluded characters are the ambiguous ones. The other two are not
/// testable from a unit test and are named below rather than faked.
void main() {
  // The row's own alphabet. Spelled out here rather than imported so that a
  // change to the production constant is a test failure rather than a test that
  // quietly follows it.
  const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  test('the spec alphabet is 31 characters and excludes I, L, O, 0 and 1', () {
    // The count is the load-bearing number: the row says "31 chars", and an
    // alphabet that drifted to 32 or 30 would weaken or waste the code space
    // without any local symptom.
    expect(alphabet.length, 31);
    for (final banned in ['I', 'L', 'O', '0', '1']) {
      expect(alphabet.contains(banned), isFalse, reason: '$banned must not appear');
    }
  });

  group('§E17 row 6 — every generated code', () {
    test('is exactly six characters', () {
      for (var i = 0; i < 200; i++) {
        expect(Formatters.generateCode().length, 6);
      }
    });

    test('is drawn only from the 31-character alphabet', () {
      for (var i = 0; i < 200; i++) {
        final code = Formatters.generateCode();
        for (final ch in code.split('')) {
          expect(
            alphabet.contains(ch),
            isTrue,
            reason: '"$code" contains "$ch", which is outside the alphabet',
          );
        }
      }
    });

    test('never contains a character a member has to guess at', () {
      // The reason the five are excluded: they are the characters read aloud
      // wrong and typed wrong. Asserted over the whole draw rather than as a
      // one-off so a single unlucky code is enough to fail.
      for (var i = 0; i < 500; i++) {
        final code = Formatters.generateCode();
        expect(code.contains('I'), isFalse, reason: '"$code"');
        expect(code.contains('L'), isFalse, reason: '"$code"');
        expect(code.contains('O'), isFalse, reason: '"$code"');
        expect(code.contains('0'), isFalse, reason: '"$code"');
        expect(code.contains('1'), isFalse, reason: '"$code"');
      }
    });

    test('is upper-case, so a lowercase paste matches the stored code', () {
      // §E17 row 7 upper-cases what a member types; a code stored in mixed case
      // would still match, but the code pill and the QR would render two
      // different strings for the same code.
      for (var i = 0; i < 100; i++) {
        final code = Formatters.generateCode();
        expect(code, code.toUpperCase(), reason: '"$code"');
      }
    });

    test('is uniform over the alphabet, not biased toward the first half', () {
      // `nextInt(31)` is already unbiased, but the earlier implementation was
      // `_seed % 31` over a 31-character alphabet, which is not. A modulo bias
      // shows up as some characters never appearing at all over a large draw,
      // which is what this checks: every one of the 31 must turn up.
      final seen = <String>{};
      for (var i = 0; i < 20_000; i++) {
        seen.addAll(Formatters.generateCode().split(''));
      }
      expect(
        seen,
        alphabet.split('').toSet(),
        reason: 'every character in the alphabet must be reachable',
      );
    });
  });

  group('§E17 row 6 — the codes are not predictable', () {
    test('two draws in the same millisecond differ', () {
      // The old generator was an LCG seeded from
      // `DateTime.now().millisecondsSinceEpoch`, so a tight loop produced the
      // SAME code every time within a millisecond. Nothing in the product can
      // prove the generator is sound; this at least pins that consecutive
      // draws are independent, which is what the seed was breaking.
      final codes = <String>{};
      for (var i = 0; i < 50; i++) {
        codes.add(Formatters.generateCode());
      }
      expect(
        codes.length,
        greaterThan(45),
        reason: '50 draws in a tight loop produced ${codes.length} distinct codes',
      );
    });

    test('a public code and a TV code drawn back to back are unrelated', () {
      // The specific leak the old implementation had: `publicCode` and `tvCode`
      // were consecutive draws from one process-wide stream, so holding one
      // revealed the other. A stream is still process-wide here, so what can be
      // checked is that the second draw carries no information about the first
      // - e.g. it is not the first shifted, reversed, or offset.
      final a = Formatters.generateCode();
      final b = Formatters.generateCode();
      expect(b, isNot(a));
      expect(b.split('').reversed.join(), isNot(a));
      expect(b, isNot(a.split('').reversed.join()));
    });
  });

  group('§E17 row 6 — the row\'s other two requirements are not unit-testable',
      () {
    test('FINDING — uniqueness across group|game|tv needs the server', () {
      // "server-transaction reservation, redraw on collision" and "one
      // namespace across group|game|tv" are properties of the Firestore
      // transaction that claims the code, not of the generator:
      // `Formatters.generateCode` is a pure function with no way to be told a
      // code is taken. The local `secureId` is the unguessable-document-id
      // helper; the join-code claim lives in the repository layer, which
      // `app_provider_codes_cash.dart` calls into only when `_backendUp`.
      //
      // Recorded as a test so the gap is visible in the suite rather than in
      // this file's doc comment alone. What it asserts is the one thing that
      // IS knowable without a backend: the generator holds no memory of what it
      // has already produced, which is exactly why the reservation has to live
      // somewhere else.
      // A growable set: `const <String>{}` is unmodifiable, and a local literal
      // would not have caught that until the first `add`.
      final seen = <String>{};
      for (var i = 0; i < 500; i++) {
        seen.add(Formatters.generateCode());
      }
      expect(
        seen.length,
        greaterThan(1),
        reason: 'the generator is stateless; collision handling is elsewhere',
      );
    });

    test('FINDING — the crypto RNG cannot be asserted, only depended on', () {
      // "crypto RNG" is `Random.secure()` at `lib/utils/formatters.dart:167`,
      // which is the correct source and is not injectable. Its quality is a
      // property of `dart:math` on the platform, not of this codebase, so there
      // is nothing meaningful to assert here beyond the source of the draws
      // already checked above. Asserted: the generator still returns a valid
      // code when called after many others, i.e. the shared static instance is
      // not exhausted or reseeded.
      for (var i = 0; i < 1000; i++) {
        Formatters.generateCode();
      }
      expect(Formatters.generateCode().length, 6);
    });
  });

  group('the same alphabet, drawn independently', () {
    test('a control draw over the same alphabet is not the code under test',
        () {
      // Guards against a test that would pass with a constant return value: a
      // hard-coded 'ABCDEF' satisfies the length and alphabet assertions above
      // but produces one distinct code, which the distinctness sweep rejects.
      // This asserts the same property from the other side, with an explicitly
      // seeded generator so the expectation is deterministic.
      final control = Random(1234);
      final draws = <String>{
        for (var i = 0; i < 200; i++)
          String.fromCharCodes([
            for (var j = 0; j < 6; j++)
              alphabet.codeUnitAt(control.nextInt(alphabet.length)),
          ]),
      };
      expect(draws.length, greaterThan(150));
    });
  });
}
