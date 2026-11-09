import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/services/recovery_service.dart';

const _structure = TournamentStructure(
  startingStack: 5000,
  chipPlan: [],
  rebuyStack: 5000,
  rebuyChipPlan: [],
  addOnStack: 5000,
  addOnChipPlan: [],
  levels: [
    BlindLevel(level: 1, sb: 25, bb: 50, ante: null, durationMins: 20),
    BlindLevel(level: 2, sb: 50, bb: 100, ante: null, durationMins: 20),
  ],
  levelDuration: 20,
  expectedFinishMins: 40,
  prizes: [],
  prizePool: 0,
  organizerAmount: 0,
  colorUpInstructions: [],
  warnings: [],
);

const _settings = GameSettings(
  name: 'Friday',
  date: '2026-09-08',
  time: '20:00',
  location: 'Basement',
  players: 8,
  durationHours: 3.5,
  buyIn: 15,
  koEnabled: false,
  koAmount: 0,
  rebuys: false,
  rebuysCloseLevel: 6,
  addOn: false,
  anteEnabled: false,
  anteAfterLevel: 7,
  organizerPct: 0,
  chipSet: [],
  chipSetName: 'Home',
);

const _host = AppUser(
  id: 'u-host',
  name: 'Host User',
  email: 'host@poker.test',
  isAdmin: true,
  stats: UserStats(
    played: 0,
    wins: 0,
    podium: 0,
    avgFinish: 0,
    knockouts: 0,
  ),
);

LiveGame _createGame({
  required String id,
  required int revision,
  LiveGameStatus status = LiveGameStatus.running,
  String? editorDeviceId,
}) =>
    LiveGame(
      id: id,
      groupId: 'g1',
      settings: _settings,
      structure: _structure,
      status: status,
      publicCode: 'CODE123',
      tvCode: 'TV123',
      currentLevel: 1,
      timerRunning: true,
      secondsRemaining: 1200,
      players: const [],
      chat: const [],
      announcements: const [],
      auditHistory: const [],
      totalChipsInPlay: 15000,
      pendingGuests: const [],
      finishOrder: const [],
      organizerIds: const [],
      revision: revision,
      editorDeviceId: editorDeviceId ?? 'dev-host',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => RecoveryService.enabled = false);
  tearDown(() => RecoveryService.enabled = true);

  test('Local revision higher than cloud does NOT trigger offline conflict', () {
    final cloudGame = _createGame(id: 'game-1', revision: 1);
    final localGame = _createGame(id: 'game-1', revision: 3);

    final group = Group(
      id: 'g1',
      name: 'Friday Crew',
      joinCode: 'JOIN123',
      ownerId: 'u-host',
      members: [_host],
      games: [cloudGame],
      chat: const [],
      polls: const [],
      notifications: const [],
    );

    final app = AppProvider()
      ..setUserForTesting(_host)
      ..setCurrentGroupForTesting(group)
      ..setCurrentGame(localGame)
      ..setRestoredFromRecoveryForTesting(true);

    // Local revision (3) > Cloud revision (1) is normal local progress, NOT a conflict
    expect(app.hasOfflineConflict, isFalse);
    app.dispose();
  });

  test('Cloud revision higher than local triggers offline conflict', () {
    final cloudGame = _createGame(id: 'game-2', revision: 5);
    final localGame = _createGame(id: 'game-2', revision: 2);

    final group = Group(
      id: 'g1',
      name: 'Friday Crew',
      joinCode: 'JOIN123',
      ownerId: 'u-host',
      members: [_host],
      games: [cloudGame],
      chat: const [],
      polls: const [],
      notifications: const [],
    );

    final app = AppProvider()
      ..setUserForTesting(_host)
      ..setCurrentGroupForTesting(group)
      ..setCurrentGame(localGame)
      ..setRestoredFromRecoveryForTesting(true);

    // Cloud revision (5) > Local revision (2) indicates remote writes supersede local
    expect(app.hasOfflineConflict, isTrue);

    // Resolving conflict clears it
    app.resolveOfflineConflict(keepLocal: true);
    expect(app.hasOfflineConflict, isFalse);
    expect(app.restoredFromRecovery, isFalse);
    app.dispose();
  });

  test('Completed or cancelled game never triggers offline conflict', () {
    final completedGame = _createGame(
      id: 'game-3',
      revision: 1,
      status: LiveGameStatus.completed,
    );

    final group = Group(
      id: 'g1',
      name: 'Friday Crew',
      joinCode: 'JOIN123',
      ownerId: 'u-host',
      members: [_host],
      games: [_createGame(id: 'game-3', revision: 10, status: LiveGameStatus.completed)],
      chat: const [],
      polls: const [],
      notifications: const [],
    );

    final app = AppProvider()
      ..setUserForTesting(_host)
      ..setCurrentGroupForTesting(group)
      ..setCurrentGame(completedGame)
      ..setRestoredFromRecoveryForTesting(true);

    expect(app.hasOfflineConflict, isFalse);
    app.dispose();
  });
}
