import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/utils/tournament_engine.dart';

const _host = AppUser(
  id: 'host',
  name: 'Host',
  email: 'host@example.com',
  isAdmin: true,
  stats: UserStats(played: 0, wins: 0, podium: 0, avgFinish: 0, knockouts: 0),
);

Player _player(int index, {int table = 1, int seat = 1}) => Player(
  id: 'p$index',
  name: 'Player $index',
  isGuest: false,
  rsvp: null,
  checkedIn: true,
  confirmed: true,
  eliminated: false,
  rebuys: 0,
  hasAddOn: false,
  knockouts: 0,
  table: table,
  seat: seat,
  active: true,
);

GameSettings _settings({bool rebuys = true, bool addOn = false}) => GameSettings(
  name: 'Quick game',
  date: '2026-10-15',
  time: '20:00',
  location: 'Kitchen table',
  players: 3,
  durationHours: 3,
  buyIn: 20,
  koEnabled: false,
  koAmount: 0,
  rebuys: rebuys,
  rebuysCloseLevel: 2,
  addOn: addOn,
  anteEnabled: false,
  anteAfterLevel: 3,
  organizerPct: 0,
  chipSet: const [],
  chipSetName: 'Quick set',
);

LiveGame _game({
  required TournamentStructure structure,
  List<Player>? players,
  bool rebuys = true,
  bool addOn = false,
  int level = 1,
  LiveGameStatus status = LiveGameStatus.running,
}) => LiveGame(
  id: 'game-1',
  groupId: 'group-1',
  settings: _settings(rebuys: rebuys, addOn: addOn),
  structure: structure,
  status: status,
  publicCode: 'ABC123',
  tvCode: 'TV1234',
  currentLevel: level,
  timerRunning: status == LiveGameStatus.running,
  secondsRemaining: 600,
  players: players ?? [_player(1, table: 1, seat: 3), _player(2, table: 1, seat: 4), _player(3, table: 1, seat: 5)],
  chat: const [],
  announcements: const [],
  totalChipsInPlay: 15000,
  pendingGuests: const [],
  finishOrder: const [],
);

Group _group(LiveGame game) => Group(
  id: 'group-1',
  name: 'Group',
  joinCode: 'CODE',
  ownerId: _host.id,
  members: const [_host],
  games: [game],
  chat: const [],
  polls: const [],
  notifications: const [],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => RecoveryService.enabled = false);
  tearDown(() => RecoveryService.enabled = true);

  group('M4: Rebuy lifecycle (B3 to B6, B15)', () {
    test('rebuy on active player preserves table and seat, increments count, no elimination', () {
      final chipSet = TournamentEngine.getPreset('Home Set (4 colour)');
      final structure = TournamentEngine.generate(TournamentParams(
        players: 3,
        durationHours: 3,
        buyIn: 20,
        chipSet: chipSet,
        rebuys: true,
        rebuysCloseLevel: 2,
        reEntry: false,
        addOn: false,
        anteEnabled: false,
        anteAfterLevel: 3,
        koEnabled: false,
        koAmount: 0,
        organizerPct: 0,
      ));

      final game = _game(structure: structure);
      final group = _group(game);
      final app = AppProvider()
        ..setUserForTesting(_host)
        ..setCurrentGroupForTesting(group)
        ..setCurrentGameForTesting(game);

      // Grant rebuy to active player 1 (seated at table 1, seat 3)
      app.grantRebuy('p1');

      final p1 = app.currentGame!.players.firstWhere((p) => p.id == 'p1');
      expect(p1.rebuys, 1);
      expect(p1.active, isTrue);
      expect(p1.eliminated, isFalse);
      expect(p1.table, 1, reason: 'Seat must be kept after a rebuy (fixes B3 / M4)');
      expect(p1.seat, 3, reason: 'Seat must be kept after a rebuy (fixes B3 / M4)');
    });

    test('rebuy on eliminated player also preserves original table and seat', () {
      final chipSet = TournamentEngine.getPreset('Home Set (4 colour)');
      final structure = TournamentEngine.generate(TournamentParams(
        players: 3,
        durationHours: 3,
        buyIn: 20,
        chipSet: chipSet,
        rebuys: true,
        rebuysCloseLevel: 2,
        reEntry: false,
        addOn: false,
        anteEnabled: false,
        anteAfterLevel: 3,
        koEnabled: false,
        koAmount: 0,
        organizerPct: 0,
      ));

      final game = _game(structure: structure, players: [
        _player(1, table: 1, seat: 5),
        _player(2, table: 1, seat: 6),
        _player(3, table: 1, seat: 7),
      ]);
      final group = _group(game);
      final app = AppProvider()
        ..setUserForTesting(_host)
        ..setCurrentGroupForTesting(group)
        ..setCurrentGameForTesting(game);

      // Eliminate player 1
      app.eliminatePlayer('p1');
      final eliminatedP1 = app.currentGame!.players.firstWhere((p) => p.id == 'p1');
      expect(eliminatedP1.eliminated, isTrue);
      expect(eliminatedP1.table, 1, reason: 'Elimination should preserve seat info');
      expect(eliminatedP1.seat, 5, reason: 'Elimination should preserve seat info');

      // Grant rebuy
      app.grantRebuy('p1');
      final reboughtP1 = app.currentGame!.players.firstWhere((p) => p.id == 'p1');
      expect(reboughtP1.eliminated, isFalse);
      expect(reboughtP1.active, isTrue);
      expect(reboughtP1.rebuys, 1);
      expect(reboughtP1.table, 1, reason: 'Seat must be kept after rebuy (fixes B3 / M4)');
      expect(reboughtP1.seat, 5, reason: 'Seat must be kept after rebuy (fixes B3 / M4)');
    });

    test('add-on break clock uses break duration from structure (fixes B6)', () {
      final chipSet = TournamentEngine.getPreset('Home Set (4 colour)');
      final structure = TournamentEngine.generate(TournamentParams(
        players: 3,
        durationHours: 3,
        buyIn: 20,
        chipSet: chipSet,
        rebuys: true,
        rebuysCloseLevel: 2,
        reEntry: false,
        addOn: true,
        anteEnabled: false,
        anteAfterLevel: 3,
        koEnabled: false,
        koAmount: 0,
        organizerPct: 0,
        breaks: const [ScheduledBreak(afterLevel: 2, durationMins: 10)],
      ));

      final game = _game(structure: structure, level: 2, rebuys: true, addOn: true);
      final group = _group(game);
      final app = AppProvider()
        ..setUserForTesting(_host)
        ..setCurrentGroupForTesting(group)
        ..setCurrentGameForTesting(game);

      // Advancing past level 2 triggers rebuy pause
      app.nextLevel();

      final pausedGame = app.currentGame!;
      expect(pausedGame.status, LiveGameStatus.rebuypause);
      expect(pausedGame.secondsRemaining, 10 * 60,
          reason: 'Add-on break must show the break length (10:00), not the next level length (fixes B6)');
    });

    test('default add-on is half stack for half buy-in (fixes B15)', () {
      final settings = GameSettings(
        name: 'Test',
        date: '2026-10-15',
        time: '20:00',
        location: 'Kitchen',
        players: 8,
        durationHours: 3,
        buyIn: 20,
        addOn: true,
        rebuys: true,
        rebuysCloseLevel: 2,
        anteEnabled: false,
        anteAfterLevel: 3,
        koEnabled: false,
        koAmount: 0,
        organizerPct: 0,
        chipSet: const [],
        chipSetName: 'Test',
      );
      expect(settings.effectiveAddOnCost, 10,
          reason: 'Default add-on cost must be half of buy-in (20 / 2 = 10)');

      final chipSet = TournamentEngine.getPreset('Home Set (4 colour)');
      final structure = TournamentEngine.generate(TournamentParams(
        players: 8,
        durationHours: 3,
        buyIn: 20,
        chipSet: chipSet,
        rebuys: true,
        rebuysCloseLevel: 2,
        reEntry: false,
        addOn: true,
        anteEnabled: false,
        anteAfterLevel: 3,
        koEnabled: false,
        koAmount: 0,
        organizerPct: 0,
      ));
      expect(structure.addOnStack, structure.startingStack ~/ 2,
          reason: 'Default add-on stack must be half of starting stack');
    });

    test('prize pool counts money received only, not future hypothetical rebuys (fixes B15)', () {
      final chipSet = TournamentEngine.getPreset('Home Set (4 colour)');
      final structure = TournamentEngine.generate(TournamentParams(
        players: 8,
        durationHours: 3,
        buyIn: 20,
        chipSet: chipSet,
        rebuys: true,
        rebuysCloseLevel: 4,
        reEntry: false,
        addOn: true,
        anteEnabled: false,
        anteAfterLevel: 3,
        koEnabled: false,
        koAmount: 0,
        organizerPct: 0,
      ));

      // 8 players * 20 buy-in = 160 gross eligible
      expect(structure.prizePool, 160,
          reason: 'Initial prize pool must reflect confirmed money received only (8 * 20 = 160)');
    });
  });
}
