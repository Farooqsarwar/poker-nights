import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:poker_night/main.dart';
import 'package:poker_night/providers/app_provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame. The provider mirrors main()'s wire-up
    // so PokerNightApp can resolve AppProvider.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppProvider(),
        child: const PokerNightApp(),
      ),
    );

    // Splash schedules a 2s navigation Timer; landing's animated suits also
    // schedule short Future.delayed timers on mount. Advance past all of them
    // so none are left pending when the test tears down.
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump(const Duration(seconds: 1));
  });
}
