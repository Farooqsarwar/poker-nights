import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/payment_record.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/repositories/firebase_repository.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/widgets/dummy_payment_sheet.dart';

Player _player(String id, {int rebuys = 0, bool hasAddOn = false}) => Player(
  id: id,
  name: id.toUpperCase(),
  isGuest: false,
  checkedIn: true,
  confirmed: true,
  eliminated: false,
  rebuys: rebuys,
  hasAddOn: hasAddOn,
  knockouts: 0,
  table: 1,
  seat: 1,
  active: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Settlement and P&L calculations (B7 / E14)', () {
    test('GameResultRow serializes and deserializes hasExplicitBuyIns correctly', () {
      final modernRow = GameResultRow(
        gameId: 'g1',
        groupId: 'grp1',
        position: 1,
        playerCount: 4,
        knockouts: 0,
        prize: 100,
        buyInsPaid: 40,
        finishedAt: DateTime(2026, 11, 1),
        hasExplicitBuyIns: true,
      );

      final map = modernRow.toMap();
      expect(map['buyInsPaid'], 40);

      final decoded = GameResultRow.fromMap('g1', map);
      expect(decoded.buyInsPaid, 40);
      expect(decoded.hasExplicitBuyIns, true);
      expect(decoded.net, 60);

      // Legacy map without buyInsPaid
      final legacyMap = <String, dynamic>{
        'gameId': 'g2',
        'groupId': 'grp1',
        'position': 2,
        'playerCount': 4,
        'knockouts': 0,
        'prize': 50,
        'finishedAt': DateTime(2026, 10, 1),
      };
      final legacyDecoded = GameResultRow.fromMap('g2', legacyMap);
      expect(legacyDecoded.buyInsPaid, 0);
      expect(legacyDecoded.hasExplicitBuyIns, false);
      expect(legacyDecoded.net, 50);
    });

    test('Settlement accounts for buyIn, rebuys, add-ons, and payment records', () {
      final playerWithLedger = _player('p1', rebuys: 2, hasAddOn: true);

      final game = LiveGame(
        id: 'game1',
        groupId: 'g1',
        settings: const GameSettings(
          name: 'Friday Tournament',
          date: '2026-11-01',
          time: '19:00',
          location: 'Home',
          players: 4,
          durationHours: 3,
          buyIn: 25,
          chipSet: [],
          chipSetName: 'Standard',
          koEnabled: false,
          koAmount: 0,
          rebuys: true,
          rebuysCloseLevel: 6,
          addOn: true,
          anteEnabled: false,
          anteAfterLevel: 1,
          organizerPct: 0,
        ),
        structure: const TournamentStructure(
          startingStack: 2000,
          chipPlan: [],
          rebuyStack: 2000,
          rebuyChipPlan: [],
          addOnStack: 2000,
          addOnChipPlan: [],
          levels: [],
          breaks: [],
          levelDuration: 15,
          expectedFinishMins: 120,
          prizes: [Prize(place: 1, amount: 75)],
          prizePool: 100,
          organizerAmount: 0,
          colorUpInstructions: [],
          warnings: [],
        ),
        status: LiveGameStatus.completed,
        publicCode: 'C1',
        tvCode: 'TV1',
        currentLevel: 5,
        timerRunning: false,
        secondsRemaining: 0,
        players: [playerWithLedger],
        chat: const [],
        announcements: const [],
        totalChipsInPlay: 5000,
        pendingGuests: const [],
        finishOrder: const ['p1'],
        payments: [
          PaymentRecord(
            id: 'pay-1',
            playerId: 'p1',
            amount: 25,
            purpose: PaymentPurpose.buyIn,
            status: PaymentStatus.paid,
            timestamp: DateTime(2026, 11, 1, 19, 0),
            idempotencyKey: 'k1',
          ),
          PaymentRecord(
            id: 'pay-2',
            playerId: 'p1',
            amount: 25,
            purpose: PaymentPurpose.rebuy,
            status: PaymentStatus.paid,
            timestamp: DateTime(2026, 11, 1, 19, 30),
            idempotencyKey: 'k2',
          ),
        ],
      );

      final app = AppProvider();
      final settlements = app.buildSettlementsForGame(game);
      expect(settlements.containsKey('p1'), isTrue);

      final row = settlements['p1']!;
      // Total buy-ins paid = 25 (recorded buyIn) + 25 (recorded rebuy) + 25 (unrecorded 2nd rebuy) + 25 (unrecorded addOn) = 100
      expect(row.buyInsPaid, 100);
      expect(row.hasExplicitBuyIns, true);
    });

    test('Comped player with 0 buyIn correctly records 0 paid', () {
      final freePlayer = _player('p2', rebuys: 0, hasAddOn: false);

      final game = LiveGame(
        id: 'game2',
        groupId: 'g1',
        settings: const GameSettings(
          name: 'Free Roll',
          date: '2026-11-01',
          time: '19:00',
          location: 'Home',
          players: 2,
          durationHours: 2,
          buyIn: 0,
          chipSet: [],
          chipSetName: 'Standard',
          koEnabled: false,
          koAmount: 0,
          rebuys: false,
          rebuysCloseLevel: 6,
          addOn: false,
          anteEnabled: false,
          anteAfterLevel: 1,
          organizerPct: 0,
        ),
        structure: const TournamentStructure(
          startingStack: 1000,
          chipPlan: [],
          rebuyStack: 1000,
          rebuyChipPlan: [],
          addOnStack: 1000,
          addOnChipPlan: [],
          levels: [],
          breaks: [],
          levelDuration: 15,
          expectedFinishMins: 60,
          prizes: [Prize(place: 1, amount: 50)],
          prizePool: 50,
          organizerAmount: 0,
          colorUpInstructions: [],
          warnings: [],
        ),
        status: LiveGameStatus.completed,
        publicCode: 'C2',
        tvCode: 'TV2',
        currentLevel: 3,
        timerRunning: false,
        secondsRemaining: 0,
        players: [freePlayer],
        chat: const [],
        announcements: const [],
        totalChipsInPlay: 2000,
        pendingGuests: const [],
        finishOrder: const ['p2'],
      );

      final app = AppProvider();
      final settlements = app.buildSettlementsForGame(game);
      expect(settlements['p2']!.buyInsPaid, 0);
      expect(settlements['p2']!.hasExplicitBuyIns, true);
    });

    test('Real Comp Path: comped player in a paid game (buyIn: 25) records 0 buyInsPaid while normal player pays 25', () {
      final compedPlayer = _player('p_comped', rebuys: 0, hasAddOn: false);
      final normalPlayer = _player('p_normal', rebuys: 0, hasAddOn: false);

      final game = LiveGame(
        id: 'game_comp',
        groupId: 'g1',
        settings: const GameSettings(
          name: 'Paid Tourney with Comped Guest',
          date: '2026-11-01',
          time: '19:00',
          location: 'Home',
          players: 2,
          durationHours: 2,
          buyIn: 25,
          chipSet: [],
          chipSetName: 'Standard',
          koEnabled: false,
          koAmount: 0,
          rebuys: false,
          rebuysCloseLevel: 6,
          addOn: false,
          anteEnabled: false,
          anteAfterLevel: 1,
          organizerPct: 0,
        ),
        structure: const TournamentStructure(
          startingStack: 1000,
          chipPlan: [],
          rebuyStack: 1000,
          rebuyChipPlan: [],
          addOnStack: 1000,
          addOnChipPlan: [],
          levels: [],
          breaks: [],
          levelDuration: 15,
          expectedFinishMins: 60,
          prizes: [Prize(place: 1, amount: 50)],
          prizePool: 25,
          organizerAmount: 0,
          colorUpInstructions: [],
          warnings: [],
        ),
        status: LiveGameStatus.running,
        publicCode: 'C3',
        tvCode: 'TV3',
        currentLevel: 1,
        timerRunning: false,
        secondsRemaining: 600,
        players: [compedPlayer, normalPlayer],
        chat: const [],
        announcements: const [],
        totalChipsInPlay: 2000,
        pendingGuests: const [],
        finishOrder: const [],
      );

      final app = AppProvider();
      app.setCurrentGame(game);

      // Record comp for p_comped
      final compRecord = app.recordComp(playerId: 'p_comped');
      expect(compRecord, isNotNull);
      expect(compRecord!.amount, 0);
      expect(compRecord.failureReason, 'comp');

      // Finish the tournament with p_comped 1st, p_normal 2nd
      final finishedGame = app.currentGame!.copyWith(
        status: LiveGameStatus.completed,
        finishOrder: const ['p_normal', 'p_comped'],
      );

      final settlements = app.buildSettlementsForGame(finishedGame);
      expect(settlements['p_comped']!.buyInsPaid, 0);
      expect(settlements['p_comped']!.hasExplicitBuyIns, true);
      expect(settlements['p_normal']!.buyInsPaid, 25);
      expect(settlements['p_normal']!.hasExplicitBuyIns, true);
    });

    testWidgets('DummyPaymentSheet displays Comp entry button for admin and records comp', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      RecoveryService.enabled = false;
      addTearDown(() => RecoveryService.enabled = true);

      final adminUser = const AppUser(
        id: 'admin_1',
        name: 'Host Admin',
        email: 'host@test.com',
        isAdmin: true,
        stats: UserStats(played: 0, wins: 0, podium: 0, avgFinish: 0, knockouts: 0),
      );

      final group = Group(
        id: 'g1',
        name: 'Group 1',
        joinCode: 'G1',
        ownerId: adminUser.id,
        members: [adminUser],
        games: const [],
        chat: const [],
        polls: const [],
        notifications: const [],
      );

      final dummyGame = LiveGame(
        id: 'game_comp',
        groupId: 'g1',
        settings: const GameSettings(
          name: 'Comp Test',
          date: '2026-11-09',
          time: '20:00',
          location: 'Club',
          players: 2,
          durationHours: 2,
          buyIn: 25,
          chipSet: [],
          chipSetName: 'Standard',
          koEnabled: false,
          koAmount: 0,
          rebuys: false,
          rebuysCloseLevel: 1,
          addOn: false,
          anteEnabled: false,
          anteAfterLevel: 1,
          organizerPct: 0,
        ),
        structure: const TournamentStructure(
          startingStack: 1000,
          chipPlan: [],
          rebuyStack: 1000,
          rebuyChipPlan: [],
          addOnStack: 0,
          addOnChipPlan: [],
          levels: [],
          breaks: [],
          levelDuration: 15,
          expectedFinishMins: 60,
          prizes: [],
          prizePool: 50,
          organizerAmount: 0,
          colorUpInstructions: [],
          warnings: [],
        ),
        status: LiveGameStatus.running,
        publicCode: 'COMP1',
        tvCode: 'TVCOMP',
        currentLevel: 1,
        timerRunning: false,
        secondsRemaining: 600,
        players: const [
          Player(
            id: 'player_123',
            name: 'Alice',
            isGuest: false,
            checkedIn: true,
            confirmed: true,
            eliminated: false,
            rebuys: 0,
            hasAddOn: false,
            knockouts: 0,
            table: 1,
            seat: 1,
            active: true,
          ),
        ],
        chat: const [],
        announcements: const [],
        totalChipsInPlay: 1000,
        pendingGuests: const [],
        finishOrder: const [],
      );

      final app = AppProvider()
        ..setUserForTesting(adminUser)
        ..setCurrentGroupForTesting(group)
        ..setCurrentGameForTesting(dummyGame);
      PaymentRecord? recorded;

      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: app,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDummyPaymentSheet(
                    context: context,
                    playerId: 'player_123',
                    playerName: 'Alice',
                    purpose: PaymentPurpose.buyIn,
                    onSettled: (r) => recorded = r,
                  ),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open payment sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Comp entry button is displayed for admin
      expect(find.text('Comp entry'), findsOneWidget);

      // Tap Comp entry
      await tester.tap(find.text('Comp entry'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Assert comp payment record was created
      expect(recorded, isNotNull);
      expect(recorded!.playerId, 'player_123');
      expect(recorded!.purpose, PaymentPurpose.buyIn);
      expect(recorded!.amount, 0);
      expect(recorded!.status, PaymentStatus.paid);
      expect(recorded!.failureReason, 'comp');

      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
    });

    test('Offline pending settlements survive Localstore persistence and hydration', () async {
      final app = AppProvider();
      final row = GameResultRow(
        gameId: 'offline_game_1',
        groupId: 'g_offline',
        position: 1,
        playerCount: 5,
        knockouts: 2,
        finishedAt: DateTime.parse('2026-11-09T10:00:00.000'),
        prize: 150,
        buyInsPaid: 30,
        hasExplicitBuyIns: true,
      );

      // Add to pending settlements
      app.pendingSettlementsForTesting['offline_game_1'] = {
        'player_1': row,
      };

      // Persist to Localstore
      await app.persistPendingSettlementsForTesting();

      // Clear in-memory pending settlements
      app.pendingSettlementsForTesting.clear();
      expect(app.pendingSettlementsForTesting, isEmpty);

      // Hydrate from Localstore
      await app.hydratePendingSettlementsForTesting();

      expect(app.pendingSettlementsForTesting, contains('offline_game_1'));
      final restored = app.pendingSettlementsForTesting['offline_game_1']!['player_1'];
      expect(restored, isNotNull);
      expect(restored!.gameId, 'offline_game_1');
      expect(restored.groupId, 'g_offline');
      expect(restored.position, 1);
      expect(restored.playerCount, 5);
      expect(restored.knockouts, 2);
      expect(restored.prize, 150);
      expect(restored.buyInsPaid, 30);
      expect(restored.hasExplicitBuyIns, isTrue);
    });
  });
}
