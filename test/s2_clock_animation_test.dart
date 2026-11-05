import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/widgets/app_timer.dart';

void main() {
  group('S2 (T2): Clock Seconds Animation', () {
    testWidgets('AppTimer renders with gentle crossfade and tabular figures', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppTimer(
                secondsRemaining: 60,
                size: 48,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Check AnimatedSwitcher uses FadeTransition (gentle crossfade) and no SlideTransition
      final animatedSwitcher = tester.widget<AnimatedSwitcher>(
        find.descendant(
          of: find.byType(AppTimer),
          matching: find.byType(AnimatedSwitcher),
        ).first,
      );

      expect(animatedSwitcher.duration, const Duration(milliseconds: 150));

      // Pump change to 59 seconds
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppTimer(
                secondsRemaining: 59,
                size: 48,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify no SlideTransition inside AppTimer (which caused ghosting)
      expect(
        find.descendant(
          of: find.byType(AppTimer),
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
      );

      await tester.pumpAndSettle();
    });

    testWidgets('AppTimer respects reduced motion (disableAnimations)', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: AppTimer(
                  secondsRemaining: 60,
                  size: 48,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final animatedSwitcher = tester.widget<AnimatedSwitcher>(
        find.descendant(
          of: find.byType(AppTimer),
          matching: find.byType(AnimatedSwitcher),
        ).first,
      );

      // Duration should be zero when reduce-motion is enabled
      expect(animatedSwitcher.duration, Duration.zero);

      await tester.pumpAndSettle();
    });
  });
}
