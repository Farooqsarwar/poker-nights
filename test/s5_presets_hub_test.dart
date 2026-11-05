import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/shell/presets_screen.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/widgets/app_tabs.dart';
import 'package:provider/provider.dart';

const _host = AppUser(
  id: 'u1',
  name: 'Alex Morgan',
  email: 'alex@poker.night',
  isAdmin: true,
  stats: UserStats(played: 1, wins: 0, podium: 0, avgFinish: 0, knockouts: 0),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => RecoveryService.enabled = false);
  tearDown(() => RecoveryService.enabled = true);

  testWidgets('S5 (P1, P3): PresetsScreen organizes Presets Hub into chip stacks, tournament presets, and styles in order', (tester) async {
    final app = AppProvider()..setUserForTesting(_host);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AppProvider>.value(
          value: app,
          child: const Scaffold(
            body: PresetsScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify tabs are present in exact order: Chip stacks -> Tournament presets -> Tournament styles
    final tabsFinder = find.byType(AppTabs);
    expect(tabsFinder, findsOneWidget);

    final appTabs = tester.widget<AppTabs>(tabsFinder);
    expect(appTabs.tabs.length, 3);
    expect(appTabs.tabs[0].label, 'Chip stacks');
    expect(appTabs.tabs[1].label, 'Tournament presets');
    expect(appTabs.tabs[2].label, 'Tournament styles');

    // Default tab is 'Chip stacks': verify stack cards
    expect(find.text('Starting chip stacks'), findsOneWidget);
    expect(find.text('Standard stack (100 BB)'), findsOneWidget);
    expect(find.text('Deep stack (150 BB)'), findsOneWidget);
    expect(find.text('Turbo stack (50 BB)'), findsOneWidget);

    // Switch to 'Tournament presets' tab
    await tester.tap(find.text('Tournament presets'));
    await tester.pumpAndSettle();
    expect(find.text('+ New'), findsOneWidget);

    // Switch to 'Tournament styles' tab
    await tester.tap(find.text('Tournament styles'));
    await tester.pumpAndSettle();
    expect(find.text('Tournament styles & formats'), findsOneWidget);
    expect(find.text('Freezeout'), findsOneWidget);
    expect(find.text('Rebuy & Add-on'), findsOneWidget);
    expect(find.text('Knockout / Bounty'), findsOneWidget);
    expect(find.text('Shootout'), findsOneWidget);

    app.dispose();
  });
}
