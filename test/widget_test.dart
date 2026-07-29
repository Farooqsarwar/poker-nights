import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PokerNightApp());
    // Basic initialization tests can go here.
  });
}
