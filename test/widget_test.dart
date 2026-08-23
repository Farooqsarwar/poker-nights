import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:poker_night/app/router.dart';
import 'package:poker_night/main.dart';
import 'package:poker_night/providers/app_provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame. Mirrors main()'s wire-up: the
    // provider instance is created first, then shared with the router's
    // auth guard via refreshListenable.
    final appProvider = AppProvider();
    final GoRouter router = buildAppRouter(appProvider);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: appProvider,
        child: PokerNightApp(router: router),
      ),
    );

    // Splash schedules a 2s navigation Timer; landing's animated suits also
    // schedule short Future.delayed timers on mount. Advance past all of them
    // so none are left pending when the test tears down. Without a Firebase
    // backend the provider marks auth ready immediately, so the splash
    // redirect lands on /landing.
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump(const Duration(seconds: 1));

    // Dispose inside the test body — the framework asserts on pending timers
    // before addTearDown callbacks run.
    router.dispose();
    appProvider.dispose();
  });
}
