import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/public/tv_mode_screen.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/utils/formatters.dart';
import 'package:poker_night/utils/share_card.dart';
import 'package:poker_night/utils/voice_service.dart';
import 'package:provider/provider.dart';

const _host = AppUser(
  id: 'host',
  name: 'Host',
  email: 'host@example.com',
  isAdmin: true,
  stats: UserStats(played: 0, wins: 0, podium: 0, avgFinish: 0, knockouts: 0),
);

const _settings = GameSettings(
  name: 'Friday game',
  date: '2026-10-17',
  time: '20:00',
  location: 'Kitchen table',
  players: 3,
  durationHours: 3,
  buyIn: 20,
  koEnabled: false,
  koAmount: 0,
  rebuys: true,
  rebuysCloseLevel: 2,
  addOn: false,
  anteEnabled: false,
  anteAfterLevel: 3,
  organizerPct: 0,
  chipSet: [],
  chipSetName: 'Home',
);

const _structure = TournamentStructure(
  startingStack: 5000,
  chipPlan: [],
  rebuyStack: 5000,
  rebuyChipPlan: [],
  addOnStack: 0,
  addOnChipPlan: [],
  levels: [
    BlindLevel(level: 1, sb: 25, bb: 50, ante: null, durationMins: 15),
    BlindLevel(level: 2, sb: 50, bb: 100, ante: null, durationMins: 15),
    BlindLevel(level: 3, sb: 75, bb: 150, ante: null, durationMins: 15),
  ],
  levelDuration: 15,
  expectedFinishMins: 45,
  prizes: [Prize(place: 1, amount: 800), Prize(place: 2, amount: 434)],
  prizePool: 1234,
  organizerAmount: 0,
  colorUpInstructions: [],
  warnings: [],
);

Player _player(int index) => Player(
  id: 'p$index',
  name: 'Player $index',
  isGuest: false,
  rsvp: null,
  checkedIn: true,
  confirmed: true,
  eliminated: false,
  rebuys: 0,
  hasAddOn: false,
  knockouts: index,
  table: 1,
  seat: index,
  active: true,
);

LiveGame _game({LiveGameStatus status = LiveGameStatus.running}) => LiveGame(
  id: 'game-1',
  groupId: 'group-1',
  settings: _settings,
  structure: _structure,
  status: status,
  publicCode: 'ABC123',
  tvCode: 'TV1234',
  currentLevel: 3,
  timerRunning: false,
  secondsRemaining: 600,
  players: [_player(1), _player(2), _player(3)],
  chat: const [],
  announcements: const [],
  totalChipsInPlay: 15000,
  pendingGuests: const [],
  finishOrder: const ['p3', 'p2', 'p1'],
  settlementConfirmed: true,
);

Group _group(LiveGame game) => Group(
  id: 'group-1',
  name: 'Friday regulars',
  joinCode: 'FRIDAY',
  ownerId: _host.id,
  members: const [_host],
  games: [game],
  chat: const [],
  polls: const [],
  notifications: const [],
);

const _currencySymbols = [r'$', '\u00a3', '\u20ac'];

bool _containsCurrencySymbol(String value) =>
    _currencySymbols.any(value.contains);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    RecoveryService.enabled = false;
    Formatters.currencySymbol = '';
  });
  tearDown(() {
    RecoveryService.enabled = true;
    Formatters.currencySymbol = '';
  });

  testWidgets('TV prize pool and payouts are symbol-free for currency None', (
    tester,
  ) async {
    final game = _game();
    final app = AppProvider()..setCurrentGameForTesting(game);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: app,
        child: const MaterialApp(home: TVModeScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('1,234'), findsOneWidget);
    expect(find.text('800'), findsWidgets);
    expect(find.text('434'), findsWidgets);
    final visibleCopy = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
        .join(' ');
    expect(_containsCurrencySymbol(visibleCopy), isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
    tester.view.reset();
  });

  test('share data and canonical voice stay symbol-free', () {
    final data = buildShareCardData(
      game: _game(),
      recap: const GameRecap(),
      showAmounts: true,
    );
    expect(data.metaLine, contains('1,234 prize pool'));
    expect(data.podium.map((entry) => entry.prizeText), contains('800'));

    final voice = [
      VoiceService.levelChangeMessage(
        level: 3,
        sb: 75,
        bb: 150,
        durationMins: 15,
      ),
      VoiceService.oneMinuteMessage(nextSb: 100, nextBb: 200),
    ].join(' ');
    expect(
      _containsCurrencySymbol(
        '${data.metaLine} ${data.podium.map((e) => e.prizeText).join(' ')}',
      ),
      isFalse,
    );
    expect(_containsCurrencySymbol(voice), isFalse);
  });

  test('settlement notification is symbol-free for currency None', () {
    final unsettled = _game(
      status: LiveGameStatus.rebuypause,
    ).copyWith(settlementConfirmed: false);
    final app = AppProvider()
      ..setUserForTesting(_host)
      ..setCurrentGroupForTesting(_group(unsettled))
      ..setCurrentGameForTesting(unsettled);

    app.confirmSettlement();
    final notification = app.notifications.last;
    expect(notification.title, 'Prize Pool confirmed');
    expect(notification.body, contains('final prize pool: 60'));
    expect(
      _containsCurrencySymbol('${notification.title} ${notification.body}'),
      isFalse,
    );
    app.dispose();
  });

  test('selecting a real symbol still affects intended money copy', () {
    Formatters.currencySymbol = r'$';
    final data = buildShareCardData(
      game: _game(),
      recap: const GameRecap(),
      showAmounts: true,
    );
    expect(Formatters.prize(1234), r'$1,234');
    expect(data.metaLine, contains(r'$1,234 prize pool'));
    expect(data.podium.map((entry) => entry.prizeText), contains(r'$800'));
  });
}
