import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';

/// Late registration closes permanently when the rebuy level ends
/// (Technical section 10.3, User Flow section 4.13).
///
/// `registrationClosed` is deliberately separate from `rebuysClosed`: the
/// settlement break is a window where an already-eliminated player may still
/// take the final rebuy from a hand that began before the deadline (12-056),
/// but nobody NEW may join. Sharing one flag meant reopening the rebuy window
/// also reopened the door.

const _structure = TournamentStructure(
  startingStack: 5000,
  chipPlan: [],
  rebuyStack: 5000,
  rebuyChipPlan: [],
  addOnStack: 5000,
  addOnChipPlan: [],
  levels: [BlindLevel(level: 1, sb: 25, bb: 50, ante: null, durationMins: 15)],
  levelDuration: 15,
  expectedFinishMins: 225,
  prizes: [],
  prizePool: 0,
  organizerAmount: 0,
  colorUpInstructions: [],
  warnings: [],
);

GameSettings _settings({required bool rebuys, int closeLevel = 6}) =>
    GameSettings(
      name: 'Friday',
      date: '2026-09-08',
      time: '20:00',
      location: 'Basement',
      players: 8,
      durationHours: 3.5,
      buyIn: 15,
      koEnabled: false,
      koAmount: 0,
      rebuys: rebuys,
      rebuysCloseLevel: closeLevel,
      addOn: true,
      anteEnabled: false,
      anteAfterLevel: 7,
      organizerPct: 0,
      chipSet: const [],
      chipSetName: 'Home',
    );

LiveGame _game({
  required bool rebuys,
  required LiveGameStatus status,
  required int level,
  bool settled = false,
}) => LiveGame(
  id: 'g1',
  groupId: 'grp1',
  settings: _settings(rebuys: rebuys),
  structure: _structure,
  status: status,
  publicCode: 'ABC123',
  tvCode: 'TV7890',
  currentLevel: level,
  timerRunning: true,
  secondsRemaining: 600,
  players: const [],
  chat: const [],
  announcements: const [],
  totalChipsInPlay: 40000,
  pendingGuests: const [],
  finishOrder: const [],
  settlementConfirmed: settled,
);

void main() {
  group('the door shuts when the rebuy level ends', () {
    test('WITH rebuys enabled', () {
      expect(
        _game(rebuys: true, status: LiveGameStatus.running, level: 6)
            .registrationClosed,
        isFalse,
        reason: 'level 6 is the last level anyone may still join',
      );
      expect(
        _game(rebuys: true, status: LiveGameStatus.running, level: 7)
            .registrationClosed,
        isTrue,
      );
    });

    test('WITHOUT rebuys enabled — the level still governs', () {
      // `rebuypause` is only ever set inside nextLevel's `shouldPauseRebuy`
      // branch, which requires `settings.rebuys`. Gating the level test on
      // that flag too left a no-rebuy tournament with no closing point at
      // all: walk-ins, guest claims and check-ins stayed open at level 12.
      expect(
        _game(rebuys: false, status: LiveGameStatus.running, level: 6)
            .registrationClosed,
        isFalse,
      );
      expect(
        _game(rebuys: false, status: LiveGameStatus.running, level: 7)
            .registrationClosed,
        isTrue,
        reason: 'a no-rebuy game must still close its door',
      );
      expect(
        _game(rebuys: false, status: LiveGameStatus.running, level: 12)
            .registrationClosed,
        isTrue,
        reason: 'and must certainly be closed deep into play',
      );
    });

    test('the settlement break and everything after it are closed', () {
      for (final st in [
        LiveGameStatus.rebuypause,
        LiveGameStatus.finaltable,
        LiveGameStatus.completed,
      ]) {
        expect(
          _game(rebuys: true, status: st, level: 6).registrationClosed,
          isTrue,
          reason: '$st must not accept new players',
        );
      }
    });

    test('the door is open before and during check-in', () {
      for (final st in [
        LiveGameStatus.published,
        LiveGameStatus.checkin,
        LiveGameStatus.ready,
        LiveGameStatus.running,
      ]) {
        expect(
          _game(rebuys: true, status: st, level: 1).registrationClosed,
          isFalse,
          reason: '$st should still admit a late arrival',
        );
      }
    });
  });

  group('rebuys stay open through settlement, registration does not', () {
    test('during the break a final rebuy is still allowed', () {
      final g = _game(
        rebuys: true,
        status: LiveGameStatus.rebuypause,
        level: 7,
      );
      expect(g.rebuysClosed, isFalse, reason: '12-056: the final rebuy');
      expect(g.registrationClosed, isTrue, reason: 'but no new players');
    });

    test('confirming settlement closes rebuys for good', () {
      final g = _game(
        rebuys: true,
        status: LiveGameStatus.rebuypause,
        level: 7,
        settled: true,
      );
      expect(g.rebuysClosed, isTrue);
      expect(g.registrationClosed, isTrue);
    });
  });
}
