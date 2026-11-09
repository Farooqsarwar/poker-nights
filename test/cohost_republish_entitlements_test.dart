import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/app/route_paths.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/tournament/rebuy_settlement_screen.dart';
import 'package:poker_night/services/entitlements.dart';
import 'package:poker_night/services/payment_service.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/utils/structure_verification.dart';
import 'package:poker_night/utils/tournament_engine.dart';
import 'package:poker_night/widgets/structure_audit_banner.dart';
import 'package:provider/provider.dart';

const _chips = [
  ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 100),
  ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 100),
  ChipColor(color: 'Blue', hex: 0xFF2980B9, value: 25, quantity: 50),
  ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 100, quantity: 30),
  ChipColor(color: 'Purple', hex: 0xFF8E44AD, value: 500, quantity: 20),
];

const _settings = GameSettings(
  name: 'Friday',
  date: '2026-09-18',
  time: '20:00',
  location: 'Kitchen table',
  players: 6,
  durationHours: 4,
  buyIn: 20,
  chipSet: _chips,
  chipSetName: 'Standard 300',
  koEnabled: false,
  koAmount: 0,
  rebuys: true,
  rebuysCloseLevel: 6,
  addOn: true,
  addOnCloseLevel: 8,
  anteEnabled: false,
  anteAfterLevel: 7,
  organizerPct: 10,
);

TournamentStructure _generate(GameSettings s) => TournamentEngine.generate(
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

Player _player(
  String id, {
  bool confirmed = true,
  bool active = true,
  bool eliminated = false,
  int rebuys = 0,
}) =>
    Player(
      id: id,
      name: id.toUpperCase(),
      isGuest: false,
      rsvp: Rsvp.going,
      checkedIn: true,
      confirmed: confirmed,
      eliminated: eliminated,
      active: active,
      rebuys: rebuys,
      hasAddOn: false,
      knockouts: 0,
      table: 1,
      seat: 1,
    );

LiveGame _game({TournamentStructure? structure}) => LiveGame(
      id: 'game-1',
      groupId: 'g1',
      settings: _settings,
      structure: structure ?? _generate(_settings),
      status: LiveGameStatus.published,
      publicCode: 'ABC123',
      tvCode: 'TV7890',
      currentLevel: 3,
      timerRunning: false,
      secondsRemaining: 900,
      players: [
        for (final id in ['u1', 'u2', 'u3', 'u4', 'u5']) _player(id),
        _player('u6', eliminated: true, active: false),
      ],
      chat: const [],
      announcements: const [],
      totalChipsInPlay: 30000,
      pendingGuests: const [],
      finishOrder: const [],
    );

TournamentStructure _doctored(TournamentStructure real) {
  final levels = [...real.levels];
  levels[3] = BlindLevel(
    level: levels[3].level,
    sb: levels[3].sb * 4,
    bb: levels[3].bb * 4,
    ante: levels[3].ante,
    durationMins: levels[3].durationMins,
  );
  return real.copyWith(levels: levels);
}

const _host = AppUser(
  id: 'u1',
  name: 'Alex Morgan',
  email: 'alex@poker.night',
  isAdmin: true,
  stats: UserStats(
    played: 34,
    wins: 6,
    podium: 11,
    avgFinish: 3.2,
    knockouts: 18,
  ),
);

const _coHost = AppUser(
  id: 'u2',
  name: 'Marco Silva',
  email: 'marco@poker.night',
  isAdmin: false,
  isCoAdmin: true,
  stats: UserStats(
    played: 21,
    wins: 4,
    podium: 8,
    avgFinish: 3.9,
    knockouts: 9,
  ),
);

const _member = AppUser(
  id: 'u3',
  name: 'Nina Kowalski',
  email: 'nina@poker.night',
  isAdmin: false,
  stats: UserStats(
    played: 12,
    wins: 2,
    podium: 4,
    avgFinish: 4.1,
    knockouts: 3,
  ),
);

const _group = Group(
  id: 'g1',
  name: 'Friday Poker Club',
  joinCode: 'FP2608',
  ownerId: 'u1',
  members: [_host, _coHost, _member],
  games: [],
  chat: [],
  polls: [],
  notifications: [],
);

AppProvider _provider(AppUser user, {LiveGame? game}) => AppProvider()
  ..setUserForTesting(user)
  ..setCurrentGroupForTesting(_group)
  ..setCurrentGame(game ?? _game());

class _LiveBanner extends StatelessWidget {
  const _LiveBanner();

  @override
  Widget build(BuildContext context) =>
      StructureAuditBanner(game: context.watch<AppProvider>().currentGame!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => RecoveryService.enabled = false);
  tearDown(() => RecoveryService.enabled = true);

  Future<void> screen(
    WidgetTester tester,
    AppProvider app,
    Widget screen, {
    String initialLocation = RoutePaths.rebuySettlement,
  }) async {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: RoutePaths.landing,
          builder: (_, _) =>
              Scaffold(backgroundColor: Colors.transparent, body: screen),
        ),
        GoRoute(
          path: RoutePaths.invitation,
          builder: (_, _) => const Scaffold(body: Text('invitation')),
        ),
        GoRoute(
          path: RoutePaths.hostDashboard,
          builder: (_, _) => const Scaffold(body: Text('host-dashboard')),
        ),
        GoRoute(
          path: RoutePaths.rebuySettlement,
          builder: (_, _) =>
              Scaffold(backgroundColor: Colors.transparent, body: screen),
        ),
      ],
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: app,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester, AppProvider app) async {
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
    await tester.pump();
  }

  group('host or co-host is the predicate, not host alone', () {
    test('a co-host runs the table without being the owner', () {
      final app = _provider(_coHost);
      try {
        expect(app.isAdmin, isFalse);
        expect(app.isCoAdmin, isTrue);
        expect(app.isHostOrCoHost, isTrue);
      } finally {
        app.dispose();
      }
    });

    test('an ordinary member runs nothing', () {
      final app = _provider(_member);
      try {
        expect(app.isHostOrCoHost, isFalse);
      } finally {
        app.dispose();
      }
    });

    test('the host is still the host', () {
      final app = _provider(_host);
      try {
        expect(app.isHostOrCoHost, isTrue);
      } finally {
        app.dispose();
      }
    });
  });

  group('C6 rebuy settlement', () {
    testWidgets('a co-host reaches the settlement steps', (t) async {
      t.view.physicalSize = const Size(1200, 2400);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      final app = _provider(_coHost);
      await screen(t, app, const RebuySettlementScreen());
      try {
        expect(
          find.text('Step 1 — Confirm who is in'),
          findsOneWidget,
          reason: 'a co-host is sent to the invitation screen instead',
        );
        expect(find.text('Final rebuy'), findsOneWidget);
        expect(find.text(kConfirmAndResumeClock), findsOneWidget);
        expect(
          find.text('Confirm player count — go to add-ons'),
          findsOneWidget,
        );
      } finally {
        await dispose(t, app);
      }
    });

    testWidgets('the host reaches them too', (t) async {
      t.view.physicalSize = const Size(1200, 2400);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      final app = _provider(_host);
      await screen(t, app, const RebuySettlementScreen());
      try {
        expect(find.text('Step 1 — Confirm who is in'), findsOneWidget);
      } finally {
        await dispose(t, app);
      }
    });

    testWidgets('an ordinary member is turned away', (t) async {
      t.view.physicalSize = const Size(1200, 2400);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      final app = _provider(_member);
      await screen(t, app, const RebuySettlementScreen());
      try {
        expect(find.text('Step 1 — Confirm who is in'), findsNothing);
        expect(find.text('Final rebuy'), findsNothing);
        expect(find.text(kConfirmAndResumeClock), findsNothing);
        expect(find.text('invitation'), findsOneWidget);
      } finally {
        await dispose(t, app);
      }
    });
  });

  group('E13 structure audit banner', () {
    testWidgets('a non-host never sees it, even on a real mismatch', (t) async {
      final app = _provider(_member, game: _game(structure: _doctored(_generate(_settings))));
      await screen(
        t,
        app,
        _LiveBanner(),
        initialLocation: RoutePaths.landing,
      );
      try {
        expect(
          StructureVerification.audit(app.currentGame!).isMismatch,
          isTrue,
          reason: 'the fixture must actually be a mismatch, or the gate is '
              'being tested against nothing',
        );
        expect(find.byType(StructureAuditBanner), findsOneWidget);
        expect(find.textContaining('republish'), findsNothing);
        expect(find.text('Republish'), findsNothing);
      } finally {
        await dispose(t, app);
      }
    });

    testWidgets('a co-host does not see it either — republishing is the '
        "host's, D15", (t) async {
      final app = _provider(_coHost, game: _game(structure: _doctored(_generate(_settings))));
      await screen(
        t,
        app,
        _LiveBanner(),
        initialLocation: RoutePaths.landing,
      );
      try {
        expect(find.textContaining('republish'), findsNothing);
      } finally {
        await dispose(t, app);
      }
    });

    testWidgets('the host sees the banner and can act on it', (t) async {
      final app = _provider(_host, game: _game(structure: _doctored(_generate(_settings))));
      await screen(
        t,
        app,
        _LiveBanner(),
        initialLocation: RoutePaths.landing,
      );
      try {
        expect(find.textContaining('republish?'), findsOneWidget);
        expect(find.text('Republish'), findsOneWidget);
        expect(
          StructureVerification.audit(app.currentGame!).isMismatch,
          isTrue,
        );
      } finally {
        await dispose(t, app);
      }
    });

    testWidgets('tapping Republish rebuilds the structure from the settings',
        (t) async {
      final app = _provider(_host, game: _game(structure: _doctored(_generate(_settings))));
      await screen(
        t,
        app,
        _LiveBanner(),
        initialLocation: RoutePaths.landing,
      );
      try {
        expect(StructureVerification.audit(app.currentGame!).isMismatch, isTrue);
        await t.ensureVisible(find.text('Republish'));
        await t.tap(find.text('Republish'));
        await t.pumpAndSettle();
        expect(
          StructureVerification.audit(app.currentGame!).isVerified,
          isTrue,
          reason: 'the republish left the structure still not matching: '
              '${StructureVerification.audit(app.currentGame!).differences.join(' | ')}',
        );
        expect(find.text('Republish'), findsNothing);
      } finally {
        await dispose(t, app);
      }
    });

    testWidgets('a verified structure shows the host nothing at all', (t) async {
      final app = _provider(_host);
      await screen(
        t,
        app,
        _LiveBanner(),
        initialLocation: RoutePaths.landing,
      );
      try {
        expect(StructureVerification.audit(app.currentGame!).isVerified, isTrue);
        expect(find.text('Republish'), findsNothing);
      } finally {
        await dispose(t, app);
      }
    });
  });

  group('D4 free / Premium split', () {
    test('chip optimisation is free on every tier', () {
      expect(
        Entitlements.allows(PremiumTier.free, PremiumFeature.chipOptimisation),
        isTrue,
      );
      expect(
        Entitlements.allows(
            PremiumTier.premium, PremiumFeature.chipOptimisation),
        isTrue,
      );
    });

    test('advanced AI recommendations are free on every tier', () {
      expect(
        Entitlements.allows(
            PremiumTier.free, PremiumFeature.advancedAiRecommendations),
        isTrue,
      );
      expect(
        Entitlements.allows(
            PremiumTier.premium, PremiumFeature.advancedAiRecommendations),
        isTrue,
      );
    });

    test('Progressive and Mystery bounties are Premium', () {
      expect(
        Entitlements.allows(PremiumTier.free, PremiumFeature.bountyFormats),
        isFalse,
      );
      expect(
        Entitlements.allows(PremiumTier.premium, PremiumFeature.bountyFormats),
        isTrue,
      );
    });

    test('graphs and exportable history are Premium', () {
      expect(
        Entitlements.allows(PremiumTier.free, PremiumFeature.exportableHistory),
        isFalse,
      );
      expect(
        Entitlements.allows(
            PremiumTier.premium, PremiumFeature.exportableHistory),
        isTrue,
      );
    });

    test('the rest of D4 Premium column is untouched', () {
      const premium = [
        PremiumFeature.multiTable,
        PremiumFeature.savedPresets,
        PremiumFeature.tvCustomisation,
        PremiumFeature.seasons,
        PremiumFeature.bountyFormats,
        PremiumFeature.exportableHistory,
      ];
      for (final f in premium) {
        expect(Entitlements.allows(PremiumTier.free, f), isFalse, reason: '$f');
        expect(Entitlements.allows(PremiumTier.premium, f), isTrue, reason: '$f');
      }
    });

    test('every feature has a label for the upgrade prompt', () {
      for (final f in PremiumFeature.values) {
        expect(f.label, isNotEmpty, reason: '$f');
      }
    });
  });
}
