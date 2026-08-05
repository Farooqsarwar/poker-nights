import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/utils/tournament_engine.dart';

void main() {
  group('Tournament payout calculation', () {
    test('Reference schedule pools 50-700 match section 25 exactly', () {
      // The approved reference style (checklist 14-028, 25-001..25-066).
      // 20 players unlocks every place count the schedule intends.
      const reference = {
        50: [40, 10],
        60: [40, 20],
        70: [50, 20],
        80: [50, 30],
        90: [60, 30],
        100: [60, 30, 10],
        110: [70, 30, 10],
        120: [70, 40, 10],
        130: [80, 40, 10],
        140: [80, 40, 20],
        150: [90, 40, 20],
        160: [90, 50, 20],
        170: [100, 50, 20],
        180: [110, 50, 20],
        190: [110, 60, 20],
        200: [110, 60, 30],
        210: [120, 60, 30],
        220: [130, 60, 30],
        230: [130, 70, 30],
        240: [140, 70, 30],
        250: [140, 80, 30],
        260: [150, 80, 30],
        270: [150, 80, 40],
        280: [160, 80, 40],
        290: [160, 90, 40],
        300: [170, 90, 40],
        310: [180, 90, 40],
        320: [180, 100, 40],
        330: [190, 100, 40],
        340: [190, 100, 50],
        350: [200, 100, 50],
        360: [200, 110, 50],
        370: [210, 110, 50],
        380: [210, 120, 50],
        390: [220, 120, 50],
        400: [220, 120, 40, 20],
        410: [230, 120, 40, 20],
        420: [240, 120, 40, 20],
        430: [240, 130, 40, 20],
        440: [250, 130, 40, 20],
        450: [250, 140, 40, 20],
        460: [260, 140, 40, 20],
        470: [260, 140, 50, 20],
        480: [270, 140, 50, 20],
        490: [270, 150, 50, 20],
        500: [280, 150, 50, 20],
        510: [290, 150, 50, 20],
        520: [290, 160, 50, 20],
        530: [300, 160, 50, 20],
        540: [300, 160, 60, 20],
        550: [310, 160, 60, 20],
        560: [310, 170, 60, 20],
        570: [320, 170, 60, 20],
        580: [320, 180, 60, 20],
        590: [330, 180, 60, 20],
        600: [330, 180, 70, 20],
        610: [340, 180, 70, 20],
        620: [340, 190, 70, 20],
        630: [350, 190, 70, 20],
        640: [350, 190, 80, 20],
        650: [360, 190, 80, 20],
        660: [360, 200, 80, 20],
        670: [370, 200, 80, 20],
        680: [370, 210, 80, 20],
        690: [380, 210, 80, 20],
        700: [390, 210, 80, 20],
      };

      for (final entry in reference.entries) {
        final prizes = TournamentEngine.calcPrizesForTest(entry.key, 20);
        final amounts = prizes.map((p) => p.amount).toList();
        expect(
          amounts,
          entry.value,
          reason: 'Pool ${entry.key}: expected ${entry.value}, got $amounts',
        );
      }
    });

    test('Guarantees hold for pools 50 to 700 in steps of 10', () {
      // Test pools from 50 to 700 in steps of 10, with enough players to
      // unlock all place counts (20 is sufficient for 4-way).
      for (int pool = 50; pool <= 700; pool += 10) {
        final prizes = TournamentEngine.calcPrizesForTest(pool, 20);

        // (a) sum == pool
        final sum = prizes.fold<int>(0, (acc, p) => acc + p.amount);
        expect(
          sum,
          pool,
          reason: 'Pool $pool: prizes must sum exactly to pool (got $sum)',
        );

        // (b) every amount is a multiple of 10
        for (final prize in prizes) {
          expect(
            prize.amount % 10,
            0,
            reason:
                'Pool $pool, place ${prize.place}: amount ${prize.amount} must be a multiple of 10',
          );
        }

        // (c) no amount ends in 5
        for (final prize in prizes) {
          final lastDigit = prize.amount % 10;
          expect(
            lastDigit,
            isNot(5),
            reason:
                'Pool $pool, place ${prize.place}: amount ${prize.amount} must not end in 5',
          );
        }

        // (d) descending (place 1 is largest, monotonic non-increasing)
        for (int i = 0; i < prizes.length - 1; i++) {
          expect(
            prizes[i].amount,
            greaterThanOrEqualTo(prizes[i + 1].amount),
            reason:
                'Pool $pool: place ${prizes[i].place} (${prizes[i].amount}) must be >= place ${prizes[i + 1].place} (${prizes[i + 1].amount})',
          );
        }

        // (e) no zero
        for (final prize in prizes) {
          expect(
            prize.amount,
            greaterThan(0),
            reason:
                'Pool $pool, place ${prize.place}: amount must be > 0 (got ${prize.amount})',
          );
        }
      }
    });

    test('Small fields pay fewer places than the pool alone allows', () {
      // Pool 300 normally pays 3 places, but a 6-player field stays at 2
      // (14-019: paid places combine unique players AND prize pool).
      final prizes = TournamentEngine.calcPrizesForTest(300, 6);
      expect(prizes.length, 2);
    });
  });

  group('Organizer rounding (14-015/14-016, UAT-054)', () {
    test('Eligible total 165 at 10% retains 15 / pool 150', () {
      // UAT-054 acceptance: an eligible total of 165 and a target near 10%
      // produces organizer 15 / prize pool 150.
      // Gross 165: 3 players @ 55 buy-in, no rebuys/add-ons.
      final structure = TournamentEngine.generate(TournamentParams(
        players: 3,
        durationHours: 3.5,
        buyIn: 55,
        chipSet: TournamentEngine.getPreset('Standard 300'),
        rebuys: false,
        rebuysCloseLevel: 4,
        addOn: false,
        anteEnabled: false,
        anteAfterLevel: 0,
        koEnabled: false,
        koAmount: 0,
        organizerPct: 10,
      ));
      expect(structure.prizePool, 150);
      expect(structure.organizerAmount, 15);
      expect(structure.prizePool + structure.organizerAmount, 165);
    });

    test('Ties prefer retaining less (14-016)', () {
      // Gross 150 @ 10% -> target 15. Valid organizers are 10 and 20 (both
      // keep the pool a multiple of 10); equally close, so keep the smaller.
      final structure = TournamentEngine.generate(TournamentParams(
        players: 3,
        durationHours: 3.5,
        buyIn: 50,
        chipSet: TournamentEngine.getPreset('Standard 300'),
        rebuys: false,
        rebuysCloseLevel: 4,
        addOn: false,
        anteEnabled: false,
        anteAfterLevel: 0,
        koEnabled: false,
        koAmount: 0,
        organizerPct: 10,
      ));
      expect(structure.prizePool, 140);
      expect(structure.organizerAmount, 10);
      expect(structure.prizePool + structure.organizerAmount, 150);
    });

    test('Zero percentage keeps everything in the pool', () {
      final structure = TournamentEngine.generate(TournamentParams(
        players: 4,
        durationHours: 3.5,
        buyIn: 50,
        chipSet: TournamentEngine.getPreset('Standard 300'),
        rebuys: false,
        rebuysCloseLevel: 4,
        addOn: false,
        anteEnabled: false,
        anteAfterLevel: 0,
        koEnabled: false,
        koAmount: 0,
        organizerPct: 0,
      ));
      expect(structure.organizerAmount, 0);
      expect(structure.prizePool, 200);
    });
  });
}
