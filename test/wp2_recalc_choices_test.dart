import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/tournament_format.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/utils/tournament_engine.dart';

/// WP2 follow-ups found by the WP1 audit: Recalculate / Start must not undo what
/// the host chose.
///  1. "Play a freeze-out" kept the stored rebuy-night stack (inert on a shallow
///     night).
///  2. A host-chosen rebuy close was replaced by the auto suggestion on every
///     recalculation (and Start recalculates).
const _host = AppUser(
  id: 'u1',
  name: 'Host',
  email: 'host@example.com',
  isAdmin: true,
  stats: UserStats(played: 0, wins: 0, podium: 0, avgFinish: 0, knockouts: 0),
);
const _group = Group(
  id: 'grp1',
  name: 'Friday',
  joinCode: 'FP2608',
  ownerId: 'u1',
  members: [_host],
  games: [],
  chat: [],
  polls: [],
  notifications: [],
);

GameSettings _settings({
  bool rebuys = true,
  int close = 0,
  bool chosen = false,
  String preset = 'Home Set (4 colour)',
}) =>
    GameSettings(
      name: 'Friday',
      date: '2026-10-12',
      time: '20:00',
      location: 'Basement',
      players: 10,
      durationHours: 4,
      buyIn: 20,
      koEnabled: false,
      koAmount: 0,
      rebuys: rebuys,
      rebuysCloseLevel: close,
      rebuyCloseChosenByOrganizer: chosen,
      addOn: rebuys,
      anteEnabled: true,
      anteAfterLevel: 6,
      organizerPct: 0,
      chipSet: TournamentEngine.getPreset(preset),
      chipSetName: preset,
      pace: PaceMode.regular,
    );

LiveGame _game(GameSettings s) {
  final structure = TournamentEngine.generate(TournamentParams(
    players: 10,
    durationHours: 4,
    buyIn: 20,
    chipSet: s.chipSet,
    rebuys: s.rebuys,
    rebuysCloseLevel: s.rebuysCloseLevel,
    rebuyCloseChosenByOrganizer: s.rebuyCloseChosenByOrganizer,
    reEntry: false,
    addOn: s.addOn,
    anteEnabled: true,
    anteAfterLevel: 6,
    koEnabled: false,
    koAmount: 0,
    organizerPct: 0,
    format: s.format,
    expectedRebuyRate: s.rebuys ? 0.35 : 0,
    addOnMultiplier: 1.25,
    pace: PaceMode.regular,
  ));
  return LiveGame(
    id: 'g1',
    groupId: 'grp1',
    settings: s,
    structure: structure,
    status: LiveGameStatus.ready,
    publicCode: 'ABC123',
    tvCode: 'TV7890',
    currentLevel: 1,
    timerRunning: false,
    secondsRemaining: 900,
    players: [
      for (var i = 0; i < 10; i++)
        Player(
          id: 'p$i',
          name: 'P$i',
          isGuest: false,
          rsvp: Rsvp.going,
          checkedIn: true,
          confirmed: true,
          eliminated: false,
          rebuys: 0,
          reEntries: 0,
          hasAddOn: false,
          knockouts: 0,
          table: 1,
          seat: i + 1,
          active: true,
        ),
    ],
    chat: const [],
    announcements: const [],
    totalChipsInPlay: 0,
    pendingGuests: const [],
    finishOrder: const [],
    seatingConfirmed: true,
  );
}

AppProvider _provider(LiveGame g) => AppProvider()
  ..setUserForTesting(_host)
  ..setCurrentGroupForTesting(_group)
  ..setCurrentGame(g);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => RecoveryService.enabled = false);

  group('"Play a freeze-out" really deals a freeze-out stack', () {
    test('Home Set, 10 players: the shallow rebuy stack is replaced', () {
      final app = _provider(_game(_settings()));
      final shallow = app.currentGame!.structure.startingStack;
      app.switchToFreezeOut();
      final g = app.currentGame!;
      final fresh = TournamentEngine.generate(TournamentParams(
        players: 10,
        durationHours: 4,
        buyIn: 20,
        chipSet: g.settings.chipSet,
        rebuys: false,
        rebuysCloseLevel: 0,
        reEntry: false,
        addOn: false,
        anteEnabled: true,
        anteAfterLevel: 6,
        koEnabled: false,
        koAmount: 0,
        organizerPct: 0,
        format: TournamentFormat.freezeOut,
        pace: PaceMode.regular,
      ));
      expect(g.structure.startingStack, fresh.startingStack);
      expect(g.structure.startingStack, greaterThan(shallow));
      expect(g.structure.isShallow, isFalse);
      app.dispose();
    });

    test('once play has started the physical stacks are NOT replaced', () {
      final g0 = _game(_settings());
      final app = _provider(g0.copyWith(
        status: LiveGameStatus.running,
        timerRunning: true,
      ));
      final before = app.currentGame!.structure.startingStack;
      app.switchToFreezeOut();
      expect(app.currentGame!.structure.startingStack, before);
      app.dispose();
    });
  });

  group('a host-chosen rebuy close survives Recalculate', () {
    test('close chosen at L6 stays L6', () {
      final app = _provider(_game(_settings(close: 6, chosen: true)));
      expect(app.currentGame!.structure.rebuysCloseLevel, 6);
      app.recalculateStructure();
      expect(app.currentGame!.structure.rebuysCloseLevel, 6);
      app.dispose();
    });

    test('an AUTO close is still auto (control)', () {
      final app = _provider(_game(_settings(close: 0, chosen: false)));
      final auto = app.currentGame!.structure.rebuysCloseLevel;
      app.recalculateStructure();
      expect(app.currentGame!.structure.rebuysCloseLevel, auto);
      app.dispose();
    });
  });
}
