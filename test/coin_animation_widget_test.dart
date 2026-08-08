import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/widgets/coin_animation_widget.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CoinAnimationWidget(
              chipAsset: Image.asset('assets/coin.png', height: 180),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('coin animation: mobile 390x844 renders cleanly', (tester) async {
    await pumpAt(tester, const Size(390, 844));
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('coin animation: desktop 1280x720 renders cleanly', (tester) async {
    await pumpAt(tester, const Size(1280, 720));
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('onAnimationComplete fires once after the slide', (tester) async {
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CoinAnimationWidget(
              loop: false,
              onAnimationComplete: () => completed++,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 600));
    expect(completed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap replays the animation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: CoinAnimationWidget()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byType(CoinAnimationWidget));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });
}
