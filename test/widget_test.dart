import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PokerNightApp());

    // Splash schedules a 2s navigation Timer; landing's animated suits also
    // schedule short Future.delayed timers on mount. Advance past all of them
    // so none are left pending when the test tears down.
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump(const Duration(seconds: 1));
  });
}
