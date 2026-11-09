import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/tournament_format.dart';
import 'package:poker_night/utils/structure_verification.dart';
import 'package:poker_night/utils/tournament_engine.dart';

/// Acceptance criterion 15 — "AI generation and sensitive mutations are not
/// trusted solely to the client" — without a server.
///
/// The mechanism is that every device can recompute the structure from the
/// tournament's own settings and compare. These tests hold that mechanism to
/// the two things that make it worth having: it must catch a doctored
/// structure, and it must NOT cry wolf over a legitimate one. The second
/// matters more — a check that fires on honest edits is one everybody learns
/// to ignore.
void main() {
  const chips = [
    ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 100),
    ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 100),
    ChipColor(color: 'Blue', hex: 0xFF2980B9, value: 25, quantity: 50),
    ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 100, quantity: 30),
    ChipColor(color: 'Purple', hex: 0xFF8E44AD, value: 500, quantity: 20),
  ];

  GameSettings settings({
    int players = 9,
    double hours = 4,
    List<ScheduledBreak> breaks = const [],
    int organizerPct = 10,
  }) =>
      GameSettings(
        name: 'Friday',
        date: '2026-09-18',
        time: '20:00',
        location: 'Kitchen table',
        durationHours: hours,
        players: players,
        buyIn: 20,
        chipSet: chips,
        chipSetName: 'Standard 300',
        koEnabled: false,
        koAmount: 0,
        rebuys: true,
        rebuysCloseLevel: 6,
        addOn: true,
        addOnCloseLevel: 8,
        anteEnabled: false,
        anteAfterLevel: 7,
        organizerPct: organizerPct,
        breaks: breaks,
      );

  TournamentStructure generate(GameSettings s) => TournamentEngine.generate(
        TournamentParams(
          players: s.players,
          durationHours: s.durationHours,
          buyIn: s.buyIn,
          chipSet: s.chipSet,
          rebuys: s.rebuys,
          rebuysCloseLevel: s.rebuysCloseLevel,
          rebuyCloseChosenByOrganizer: s.rebuyCloseChosenByOrganizer,
          reEntry: s.reEntry,
          addOn: s.addOn,
          anteEnabled: s.anteEnabled,
          anteAfterLevel: s.anteAfterLevel,
          anteStyle: s.anteStyle,
          koEnabled: s.koEnabled,
          koAmount: s.koAmount,
          organizerPct: s.organizerPct,
          rebuyCost: s.rebuyCost,
          addOnCost: s.addOnCost,
          breaks: s.breaks,
        ),
      );

  LiveGame game(GameSettings s, TournamentStructure st) => LiveGame(
        id: 'g1',
        groupId: 'grp1',
        settings: s,
        structure: st,
        status: LiveGameStatus.running,
        publicCode: 'ABC123',
        tvCode: 'TV1234',
        currentLevel: 1,
        timerRunning: false,
        secondsRemaining: 600,
        players: const [],
        chat: const [],
        announcements: const [],
        totalChipsInPlay: 0,
        pendingGuests: const [],
        finishOrder: const [],
      );

  group('an honest structure verifies', () {
    test('freshly generated, it matches', () {
      final s = settings();
      final audit = StructureVerification.audit(game(s, generate(s)));
      expect(
        audit.verdict,
        StructureVerdict.verified,
        reason: audit.differences.join(' | '),
      );
    });

    test('with breaks, it still matches', () {
      final s = settings(
        breaks: const [ScheduledBreak(afterLevel: 6, durationMins: 10)],
      );
      final audit = StructureVerification.audit(game(s, generate(s)));
      expect(audit.isVerified, isTrue, reason: audit.differences.join(' | '));
    });

    test('across a sweep of fields and durations', () {
      for (final players in [4, 9, 18, 40]) {
        for (final hours in [3.0, 4.0, 5.0, 6.0]) {
          final s = settings(players: players, hours: hours);
          final audit = StructureVerification.audit(game(s, generate(s)));
          expect(
            audit.isVerified,
            isTrue,
            reason: '$players players @ ${hours}h: '
                '${audit.differences.join(' | ')}',
          );
        }
      }
    });

    test('the organizer percentage is never needed to verify', () {
      // A player cannot see it (§23), so requiring it would make the check
      // impossible on exactly the devices it exists to serve.
      final s = settings(organizerPct: 20);
      final structure = generate(s);
      final asPlayerSees = s.copyWith(organizerPct: 0);
      final audit = StructureVerification.audit(game(asPlayerSees, structure));
      expect(audit.isVerified, isTrue, reason: audit.differences.join(' | '));
    });
  });

  group('a doctored structure is caught', () {
    test('a shallower starting stack', () {
      final s = settings();
      final real = generate(s);
      final doctored = real.copyWith(startingStack: real.startingStack ~/ 2);
      final audit = StructureVerification.audit(game(s, doctored));
      expect(audit.isMismatch, isTrue);
      expect(audit.differences.first, contains('Starting stack'));
    });

    test('a blind level quietly changed', () {
      final s = settings();
      final real = generate(s);
      final levels = [...real.levels];
      levels[3] = BlindLevel(
        level: levels[3].level,
        sb: levels[3].sb * 4,
        bb: levels[3].bb * 4,
        ante: levels[3].ante,
        durationMins: levels[3].durationMins,
      );
      final audit = StructureVerification.audit(
        game(s, real.copyWith(levels: levels)),
      );
      expect(audit.isMismatch, isTrue);
      expect(audit.differences.join(), contains('Level 4'));
    });

    test('a break moved or lengthened', () {
      final s = settings(
        breaks: const [ScheduledBreak(afterLevel: 6, durationMins: 10)],
      );
      final real = generate(s);
      final audit = StructureVerification.audit(
        game(
          s,
          real.copyWith(
            breaks: const [ScheduledBreak(afterLevel: 2, durationMins: 45)],
          ),
        ),
      );
      expect(audit.isMismatch, isTrue);
    });

    test('level duration stretched', () {
      final s = settings();
      final real = generate(s);
      final audit = StructureVerification.audit(
        game(s, real.copyWith(levelDuration: real.levelDuration + 10)),
      );
      expect(audit.isMismatch, isTrue);
      expect(audit.differences.join(), contains('minutes'));
    });

    test('many differences are summarised, not dumped', () {
      final s = settings();
      final real = generate(s);
      final levels = [
        for (final l in real.levels)
          BlindLevel(
            level: l.level,
            sb: l.sb * 3,
            bb: l.bb * 3,
            ante: l.ante,
            durationMins: l.durationMins,
          ),
      ];
      final audit = StructureVerification.audit(
        game(s, real.copyWith(levels: levels)),
      );
      expect(audit.isMismatch, isTrue);
      expect(audit.differences.length, lessThanOrEqualTo(6));
      expect(audit.differences.last, contains('more'));
    });
  });

  group('it does not cry wolf', () {
    test('a manually edited level is not tampering', () {
      // Sections 11 and 29 make manual edits legitimate and marked. Reporting
      // them would train people to ignore the warning that matters.
      final s = settings();
      final real = generate(s);
      final levels = [...real.levels];
      levels[5] = BlindLevel(
        level: levels[5].level,
        sb: levels[5].sb * 7,
        bb: levels[5].bb * 7,
        ante: levels[5].ante,
        durationMins: levels[5].durationMins,
        manuallyEdited: true,
      );
      final audit = StructureVerification.audit(
        game(s, real.copyWith(levels: levels)),
      );
      expect(
        audit.isVerified,
        isTrue,
        reason: 'a marked human edit was reported as a mismatch: '
            '${audit.differences.join(' | ')}',
      );
    });
  });

  group('"cannot tell" is never reported as "wrong"', () {
    test('no chip set on this device', () {
      final s = settings();
      final real = generate(s);
      final audit = StructureVerification.audit(
        game(s.copyWith(chipSet: const []), real),
      );
      expect(audit.verdict, StructureVerdict.cannotVerify);
      expect(audit.isMismatch, isFalse);
      expect(audit.reason, isNotNull);
    });

    test('no head count', () {
      final s = settings();
      final real = generate(s);
      final audit = StructureVerification.audit(
        game(s.copyWith(players: 0), real),
      );
      expect(audit.verdict, StructureVerdict.cannotVerify);
    });

    test('no structure at all', () {
      final s = settings();
      final real = generate(s);
      final audit = StructureVerification.audit(
        game(s, real.copyWith(levels: const [])),
      );
      expect(audit.verdict, StructureVerdict.cannotVerify);
    });

    test('older engine version', () {
      final s = settings();
      final real = generate(s);
      final audit = StructureVerification.audit(
        game(s, real.copyWith(engineVersion: '1.0.0')),
      );
      expect(audit.verdict, StructureVerdict.cannotVerify);
      expect(audit.reason, contains('engine v1.0.0'));
    });
  });

  test('the engine is deterministic — the whole mechanism rests on it', () {
    // If this ever fails, every device will disagree with every other and the
    // verification becomes noise. It is the load-bearing assumption.
    final s = settings(players: 13, hours: 5);
    final a = generate(s);
    final b = generate(s);
    expect(a.startingStack, b.startingStack);
    expect(a.levelDuration, b.levelDuration);
    expect(a.levels.length, b.levels.length);
    for (var i = 0; i < a.levels.length; i++) {
      expect(a.levels[i].sb, b.levels[i].sb);
      expect(a.levels[i].bb, b.levels[i].bb);
      expect(a.levels[i].ante, b.levels[i].ante);
    }
  });

  group('TournamentFormat and maxReEntries', () {
    test('a settings map with rebuys:true and no format resolves to rebuy', () {
      final s = settings(players: 5).copyWith(rebuys: true, format: null, reEntry: false);
      expect(s.effectiveFormat, TournamentFormat.rebuy);
    });

    test('reEntry wins over rebuys when both are set', () {
      final s = settings(players: 5).copyWith(rebuys: true, format: null, reEntry: true);
      expect(s.effectiveFormat, TournamentFormat.reEntry);
    });

    test('maxReEntries blocks the (n+1)th re-entry', () {
      final s = settings(players: 5).copyWith(reEntry: true, maxReEntries: 1, format: TournamentFormat.reEntry);
      final g = game(s, generate(s));
      final p = Player(
        id: 'p1', name: 'P1', active: true, eliminated: true, reEntries: 1, rebuys: 0,
        checkedIn: true, confirmed: true, table: 1, seat: 1, isGuest: false,
        knockouts: 0, hasAddOn: false
      );
      expect(g.canReEnter(p), isFalse);
    });
  });
}
