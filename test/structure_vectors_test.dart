import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/tournament_format.dart';
import 'package:poker_night/utils/tournament_engine.dart';

/// Structure vectors for Build Spec v3.1 §F1 and the General Poker Tournament
/// Structuring Framework.
///
/// WHY THIS FILE EXISTS, AND WHAT IT IS NOT.
///
/// Addendum 1 §1 makes `research/structure_engine.js` and its 759 assertions
/// the authority for this maths. Those files were never in this repository and
/// could not be recovered (see `PROVENANCE.md` §1.2), so those 759 assertions
/// cannot be run. **This file is not a substitute for them** and must not be
/// described as one.
///
/// What it does instead is check the things that CAN be checked without the
/// reference engine:
///
///  1. The Framework's algebraic identities. These are derivations, not
///     calibration choices, so they hold for any correct implementation
///     regardless of which constants the spec picked — which makes them the
///     one genuinely independent check available here.
///  2. §F1.2's constants and §F1.3's solver behaviour, read straight from the
///     specification's own tables.
void main() {
  // A chip case with enough of everything that bank feasibility is never the
  // thing under test.
  const chips = [
    ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 300),
    ChipColor(color: 'Red', hex: 0xFFD53032, value: 5, quantity: 300),
    ChipColor(color: 'Green', hex: 0xFF3FBF6B, value: 25, quantity: 300),
    ChipColor(color: 'Black', hex: 0xFF141414, value: 100, quantity: 300),
    ChipColor(color: 'Purple', hex: 0xFF7A3FBF, value: 500, quantity: 200),
  ];

  TournamentParams params({
    int players = 12,
    double hours = 4,
    PaceMode? pace,
    bool rebuys = false,
    bool addOn = false,
    String? startTime,
    String? endBy,
    double? rebuyRate,
    bool ante = false,
  }) =>
      TournamentParams(
        players: players,
        durationHours: hours,
        buyIn: 50,
        chipSet: chips,
        rebuys: rebuys,
        rebuysCloseLevel: 6,
        addOn: addOn,
        anteEnabled: ante,
        anteAfterLevel: 6,
        koEnabled: false,
        koAmount: 0,
        organizerPct: 0,
        pace: pace,
        startTime: startTime,
        endBy: endBy,
        expectedRebuyRate: rebuyRate,
        format: rebuys ? TournamentFormat.rebuy : TournamentFormat.freezeOut,
      );

  group('Framework §3 — the structural unit', () {
    test('D0 = X / B0: starting depth is the stack over the opening big blind',
        () {
      for (final pace in PaceMode.values) {
        final s = TournamentEngine.generate(params(pace: pace));
        final d0 = s.startingStack / s.levels.first.bb;

        // The identity itself is a tautology; what it pins is that the engine
        // reports a stack and an opening blind that actually correspond, and
        // that the result is a sane poker depth rather than a push-fold game.
        expect(d0, greaterThan(0));
        expect(
          d0,
          greaterThanOrEqualTo(TournamentEngine.kMinPlayableDepthBB.toDouble()),
          reason: '§F1.2 MIN_PLAYABLE_DEPTH — ${pace.label} opened at '
              '${d0.toStringAsFixed(1)} BB',
        );
      }
    });

    test('a bigger field never opens deeper than a smaller one, all else equal',
        () {
      // Framework §5: more entrants means more chips in play, so the same
      // clock has more depth to burn through.
      var previous = double.infinity;
      for (final players in [6, 9, 12, 18]) {
        final s = TournamentEngine.generate(
          params(players: players, pace: PaceMode.regular),
        );
        final d0 = s.startingStack / s.levels.first.bb;
        expect(d0, lessThanOrEqualTo(previous + 1e-9));
        previous = d0;
      }
    });
  });

  group('Framework §4 / Appendix — the chip-inflation model', () {
    // C = N·X + R·rebuy_size + S·add_on_size, i.e. C/X = N(1 + r + Aq).
    //
    // The engine does not expose C directly, so it is reconstructed from the
    // stacks it reports — which is the point: if the engine's own numbers do
    // not satisfy the identity, the parts disagree with each other.
    double reconstructC(TournamentStructure s, TournamentParams p) {
      final n = p.players;
      final x = s.startingStack;
      return x * n +
          s.rebuyStack * p.effectiveExpectedRebuys +
          s.addOnStack * p.effectiveExpectedAddOns +
          p.effectiveEarlyArrivalPct * x * n;
    }

    test('a freeze-out with no bonus has exactly C = N·X', () {
      final p = params(pace: PaceMode.regular);
      final s = TournamentEngine.generate(p);
      expect(reconstructC(s, p), s.startingStack * p.players.toDouble());
    });

    test('C/X = N(1 + r + Aq) when the rebuy is one starting stack', () {
      final p = params(
        pace: PaceMode.regular,
        rebuys: true,
        addOn: true,
        rebuyRate: 1.0,
      );
      final s = TournamentEngine.generate(p);

      // The Framework's normalised form, using the engine's own take-up.
      final x = s.startingStack.toDouble();
      final n = p.players;
      final r = p.effectiveExpectedRebuys / n;
      final a = s.addOnStack / x;
      final q = p.effectiveExpectedAddOns / n;

      expect(
        reconstructC(s, p) / x,
        closeTo(n * (1 + r + a * q), 1e-6),
        reason: 'Framework Appendix — normalised supply',
      );
    });

    test('rebuys increase the supply, and the blinds compress further for it',
        () {
      // Framework §5: "The blind schedule alone cannot describe the pressure
      // because chip supply changes."
      //
      // Measured in BIG BLINDS, not raw chips. Framework §17 — "absolute chip
      // labels are secondary" — and here that is not a style preference: a
      // rebuy night has to reserve chips for the forecast rebuys, so the box
      // often funds a SMALLER starting stack than the same freeze-out. Its
      // final blind can therefore be a smaller number while representing far
      // more compression. The ratio is the thing that must move.
      final freeze = TournamentEngine.generate(params(pace: PaceMode.regular));
      final rebuy = TournamentEngine.generate(
        params(pace: PaceMode.regular, rebuys: true, rebuyRate: 1.0),
      );

      double endDepthRatio(TournamentStructure s) =>
          s.levels[s.effectivePlannedLevels - 1].bb / s.startingStack;

      expect(
        endDepthRatio(rebuy),
        greaterThan(endDepthRatio(freeze)),
        reason: 'a rebuy night ends with the big blind a larger share of the '
            'starting stack than the same freeze-out',
      );
    });

    test('take-up feeds C: a higher forecast means a bigger final blind', () {
      // §F1.3 `C = … + addOnMult × S × N × takeUp + …`. The take-up is the
      // only thing that differs here, so the end target must move with it.
      final low = TournamentEngine.generate(
        params(pace: PaceMode.regular, addOn: true).copyWith(
          addOnTakeUpRate: 0.2,
        ),
      );
      final high = TournamentEngine.generate(
        params(pace: PaceMode.regular, addOn: true).copyWith(
          addOnTakeUpRate: 1.0,
        ),
      );
      expect(
        high.levels[high.effectivePlannedLevels - 1].bb,
        greaterThan(low.levels[low.effectivePlannedLevels - 1].bb),
      );
    });

    test('take-up does NOT shrink the chip bank (§F1.5 point 1)', () {
      // "…never the chip bank check, which assumes every player takes the
      // add-on." This is the property that makes forecasting take-up safe at
      // all: a 20 % forecast must not let the engine claim a box covers a
      // field it cannot actually deal to.
      //
      // A case deliberately too small for the field, so feasibility is the
      // thing under test rather than an irrelevance.
      const tightCase = [
        ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 40),
        ChipColor(color: 'Red', hex: 0xFFD53032, value: 5, quantity: 40),
        ChipColor(color: 'Green', hex: 0xFF3FBF6B, value: 25, quantity: 20),
      ];
      TournamentStructure gen(double takeUp) => TournamentEngine.generate(
            TournamentParams(
              players: 18,
              durationHours: 4,
              buyIn: 50,
              chipSet: tightCase,
              rebuys: true,
              rebuysCloseLevel: 6,
              addOn: true,
              anteEnabled: false,
              anteAfterLevel: 6,
              koEnabled: false,
              koAmount: 0,
              organizerPct: 0,
              pace: PaceMode.regular,
              addOnTakeUpRate: takeUp,
              format: TournamentFormat.rebuy,
            ),
          );

      // Whatever the forecast says, the bank verdict is the same — it is sized
      // on every player taking one, not on the forecast.
      expect(gen(0.2).feasible, gen(1.0).feasible);
      expect(gen(0.2).startingStack, gen(1.0).startingStack);
    });

    test('the early-arrival bonus is chips in play, not a rounding detail', () {
      // This is the term §F1.3 specifies and the engine was missing. With a
      // 12.5 % bonus across the field it is an eighth of the starting chips —
      // far too much to leave out of BB_end = C / K.
      final without = TournamentEngine.generate(params(pace: PaceMode.regular));
      final with_ = TournamentEngine.generate(
        params(pace: PaceMode.regular).copyWith(
          earlyArrivalBonusEnabled: true,
        ),
      );
      expect(with_.startingStack, without.startingStack);
      expect(
        with_.levels[with_.effectivePlannedLevels - 1].bb,
        greaterThanOrEqualTo(
          without.levels[without.effectivePlannedLevels - 1].bb,
        ),
        reason: 'more chips in play must not produce a smaller final blind',
      );
    });
  });

  group('Framework §6 / §F1.3 — designing for a fixed finish time', () {
    test('T = finish − start, and it crosses midnight', () {
      expect(clockDiffMinutes('20:00', '00:30'), 4 * 60 + 30);
      expect(clockDiffMinutes('19:00', '23:00'), 4 * 60);
      expect(clockDiffMinutes('23:30', '00:15'), 45);
      expect(clockDiffMinutes('nonsense', '00:15'), isNull);
      expect(clockDiffMinutes('25:00', '00:15'), isNull);
    });

    test('P = T − breaks − rebuy pause, floored at 30', () {
      expect(
        TournamentEngine.playMinutesFor(
          targetMinutes: 240,
          scheduledBreakMins: 20,
          format: TournamentFormat.freezeOut,
        ),
        220,
        reason: 'a freeze-out has no settlement hold (§F1.2)',
      );
      expect(
        TournamentEngine.playMinutesFor(
          targetMinutes: 240,
          scheduledBreakMins: 20,
          format: TournamentFormat.rebuy,
        ),
        210,
        reason: '§F1.2 rebuy pause is 10 minutes',
      );
      expect(
        TournamentEngine.playMinutesFor(
          targetMinutes: 20,
          scheduledBreakMins: 0,
          format: TournamentFormat.freezeOut,
        ),
        30,
        reason: 'floored at 30',
      );
    });

    test('a start/end window overrides the stated duration', () {
      final p = params(hours: 9, startTime: '20:00', endBy: '00:30');
      expect(p.effectiveTargetMinutes, 270);
    });

    test('a late start shrinks T while endBy is kept (§E17 row 21)', () {
      final onTime = params(startTime: '20:00', endBy: '00:30');
      final late = params(startTime: '21:00', endBy: '00:30');
      expect(onTime.effectiveTargetMinutes, 270);
      expect(late.effectiveTargetMinutes, 210);
      expect(
        late.effectiveTargetMinutes,
        lessThan(onTime.effectiveTargetMinutes),
      );
    });
  });

  group('§F1.2 — the PACE table', () {
    test('one level length all night: Turbo 15, Regular 20, Deep 30', () {
      expect(PaceMode.turbo.levelMinutes, 15);
      expect(PaceMode.regular.levelMinutes, 20);
      expect(PaceMode.deep.levelMinutes, 30);
    });

    test('growth ceilings are 1.6 / 1.5 / 1.45', () {
      expect(PaceMode.turbo.gMax, 1.6);
      expect(PaceMode.regular.gMax, 1.5);
      expect(PaceMode.deep.gMax, 1.45);
    });

    test('every generated level uses the pace length, all night', () {
      for (final pace in PaceMode.values) {
        final s = TournamentEngine.generate(params(pace: pace));
        expect(s.levelDuration, pace.levelMinutes);
        expect(
          s.levels.map((l) => l.durationMins).toSet(),
          {pace.levelMinutes},
          reason: '${pace.label}: the spec fixes ONE length for the night',
        );
      }
    });
  });

  group('§F1.3 — solveUniformLevels', () {
    test('growth is never above the pace ceiling, however steep the climb', () {
      for (final pace in PaceMode.values) {
        final r = TournamentEngine.solveUniformLevels(
          openingBB: 10,
          // Absurdly high end target, to force the clamp.
          endBB: 10000000,
          pace: pace,
          playMinutes: 120,
        );
        expect(r.growth, lessThanOrEqualTo(pace.gMax + 1e-12));
        expect(r.fits, isFalse, reason: 'this cannot fit in two hours');
        expect(r.overBy, greaterThan(0));
      }
    });

    test('growth is never below PACE_G_MIN', () {
      final r = TournamentEngine.solveUniformLevels(
        openingBB: 100,
        endBB: 110, // a climb so gentle it would solve well under 1.2
        pace: PaceMode.deep,
        playMinutes: 600,
      );
      expect(r.growth, greaterThanOrEqualTo(kPaceGMin - 1e-12));
    });

    test('a comfortable night fits and lands on its end target', () {
      // A 40× climb over twelve 20-minute levels needs g ≈ 1.398, inside
      // Regular's 1.5 ceiling. (A 100× climb over the same window needs
      // ≈ 1.52 and correctly does NOT fit — see the test below.)
      final r = TournamentEngine.solveUniformLevels(
        openingBB: 20,
        endBB: 800,
        pace: PaceMode.regular,
        playMinutes: 240,
      );
      expect(r.fits, isTrue);
      expect(r.overBy, 0);
      // BB1 × g^(e−1) reaches BB_end.
      final reached = 20 * math.pow(r.growth, r.levels - 1);
      expect(reached, greaterThanOrEqualTo(800 * 0.98));
    });

    test('a climb steeper than the ceiling does not fit, and says so', () {
      // 100× over a four-hour Regular night needs g ≈ 1.52 against a 1.5
      // ceiling, and at the ceiling it needs 13 levels (260 min) in a 240-min
      // window — past the 5-minute tolerance. This is the case `paceOptions`
      // exists to warn about rather than quietly accept.
      final r = TournamentEngine.solveUniformLevels(
        openingBB: 20,
        endBB: 2000,
        pace: PaceMode.regular,
        playMinutes: 240,
      );
      expect(r.fits, isFalse);
      expect(r.growth, PaceMode.regular.gMax);
      expect(r.overBy, greaterThan(0));
    });

    test('a fraction of a level over still counts as fitting (5 min tolerance)',
        () {
      // §F1.3: `fits = gFit ≤ gMax or levelsNeeded × L ≤ P + 5`. A window five
      // minutes short of a whole number of levels must still fit.
      final r = TournamentEngine.solveUniformLevels(
        openingBB: 20,
        endBB: 800,
        pace: PaceMode.regular,
        playMinutes: 235,
      );
      expect(r.fits, isTrue);
    });

    test('e never exceeds the levels the window actually holds when it fits',
        () {
      final r = TournamentEngine.solveUniformLevels(
        openingBB: 20,
        endBB: 400,
        pace: PaceMode.regular,
        playMinutes: 200, // 10 levels
      );
      expect(r.fits, isTrue);
      expect(r.levels, lessThanOrEqualTo(10));
    });

    test('a degenerate target at or below the opening blind does not explode',
        () {
      final r = TournamentEngine.solveUniformLevels(
        openingBB: 500,
        endBB: 100,
        pace: PaceMode.regular,
        playMinutes: 240,
      );
      expect(r.levels, greaterThanOrEqualTo(2));
      expect(r.growth.isFinite, isTrue);
    });
  });

  group('§F1.3 — paceOptions', () {
    test('offers every pace it can build, with depth and finish for each', () {
      final o = TournamentEngine.paceOptions(params());
      expect(o.options, isNotEmpty);
      for (final option in o.options) {
        expect(option.openingBB, greaterThan(0));
        expect(option.levels, greaterThanOrEqualTo(2));
        expect(option.levelMinutes, option.pace.levelMinutes);
        expect(option.startingDepthBB, greaterThan(0));
      }
    });

    test('turbo is never recommended', () {
      // Across a wide sweep of fields and windows, the recommendation must
      // never be turbo — the spec is absolute about this.
      for (final players in [4, 8, 12, 20]) {
        for (final hours in [2.0, 3.0, 4.0, 6.0]) {
          final o = TournamentEngine.paceOptions(
            params(players: players, hours: hours),
          );
          expect(
            o.recommended,
            isNot(PaceMode.turbo),
            reason: '$players players / ${hours}h recommended turbo',
          );
        }
      }
    });

    test('the recommendation is the slowest that fits, Deep before Regular',
        () {
      final o = TournamentEngine.paceOptions(params(hours: 6));
      if (o.recommended != null) {
        final deep =
            o.options.where((x) => x.pace == PaceMode.deep).firstOrNull;
        if (deep != null && deep.fits && deep.bankOk) {
          expect(o.recommended, PaceMode.deep);
        }
      }
    });

    test('when nothing fits it warns and names choices, recommending nothing',
        () {
      // A big field in a very short window: no pace can absorb it.
      final o = TournamentEngine.paceOptions(
        params(players: 30, hours: 1, rebuys: true, addOn: true),
      );
      if (o.recommended == null) {
        expect(o.warning, isNotNull);
        expect(o.warning, contains('regular pace'));
        expect(o.choices, contains('later'));
        expect(o.choices, contains('turbo'));
        expect(
          o.choices,
          contains('noAddOn'),
          reason: 'the add-on is on, so dropping it is a real choice',
        );
      }
    });

    test('nothing is applied silently — paceOptions does not mutate its input',
        () {
      final p = params();
      expect(p.pace, isNull);
      TournamentEngine.paceOptions(p);
      expect(p.pace, isNull, reason: '§E17 row 20');
    });
  });

  group('§F1.2 — the settlement hold', () {
    test('is 10 minutes, and only for rebuy and re-entry', () {
      expect(TournamentEngine.settlementBreakMins, 10);
      expect(
        TournamentEngine.settlementPauseFor(TournamentFormat.rebuy),
        10,
      );
      expect(
        TournamentEngine.settlementPauseFor(TournamentFormat.reEntry),
        10,
      );
      expect(
        TournamentEngine.settlementPauseFor(TournamentFormat.freezeOut),
        0,
        reason: 'a freeze-out has nothing to settle',
      );
    });
  });

  group('§F1.2 — the spare tail', () {
    test('four levels are published past the target finish', () {
      for (final pace in PaceMode.values) {
        final s = TournamentEngine.generate(params(pace: pace));
        expect(
          s.levels.length - s.effectivePlannedLevels,
          4,
          reason: '§F1.2 SPARE_LEVELS',
        );
      }
    });

    test('the spare levels keep climbing', () {
      final s = TournamentEngine.generate(params(pace: PaceMode.regular));
      for (var i = s.effectivePlannedLevels; i < s.levels.length; i++) {
        expect(s.levels[i].bb, greaterThan(s.levels[i - 1].bb));
      }
    });
  });
}
