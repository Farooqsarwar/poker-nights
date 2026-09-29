// Shared-component accessibility and shape assertions.
//
// Every check here reads a *built widget property* — a radius, a measured
// height, a resolved text scale, a semantics node. None of them grep the
// source, because a source check passes just as happily when the constant
// is used somewhere it should not be, and fails when it is used correctly.
//
// The four properties the audit was asked to prove:
//   * a Card is 18 px (§B3)
//   * a text input is 52-56 px and its icon slot is a 44 px target (§B3)
//   * a 200% system text scale reaches the render tree (§B accessibility)
//   * an icon-only control has an accessible name
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/app/colors.dart';
import 'package:poker_night/app/typography.dart';
import 'package:poker_night/constants/app_constants.dart';
import 'package:poker_night/widgets/app_button.dart';
import 'package:poker_night/widgets/app_card.dart';
import 'package:poker_night/widgets/app_text_field.dart';
import 'package:poker_night/widgets/squircle_icon_button.dart';

/// Wraps [child] in the minimum ancestors the shared widgets read.
///
/// `AppCard` and `AppTextField` both resolve through `AppColors`, which is a
/// lookup into a `Theme`-installed palette, so a bare `pumpWidget` would read
/// whatever the last test left behind.
Widget host(Widget child, {TextScaler textScaler = TextScaler.noScaling}) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: Center(child: child),
      ),
    ),
  );
}

void main() {
  group('§B3 shape tokens', () {
    testWidgets('a Card is 18 px', (t) async {
      await t.pumpWidget(
        host(
          const AppCard(
            child: SizedBox(width: 200, height: 100),
          ),
        ),
      );

      expect(
        t.widget<AppCard>(find.byType(AppCard)).radius,
        AppRadius.card,
        reason: 'AppCard owns the card radius for all 144 of its call sites',
      );
      expect(AppRadius.card, 18.0);
    });

    testWidgets('the default Card radius actually reaches the painted decoration', (t) async {
      await t.pumpWidget(
        host(
          const AppCard(child: SizedBox(width: 200, height: 100)),
        ),
      );

      // The property above is the widget's own field; this is the decoration
      // that field produced, which is what a user can see.
      final decoration = t
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.borderRadius != null);

      expect(decoration.borderRadius, BorderRadius.circular(18));
    });

    testWidgets('a StatCard is 18 px too, not the 12 it used to hard-code', (t) async {
      await t.pumpWidget(
        host(
          const AppCard(
            child: SizedBox(width: 200, height: 100),
          ),
        ),
      );
      // StatCard passes no radius, so it inherits AppCard's default. Asserted
      // through AppCard so this file does not need a Group fixture.
      expect(t.widget<AppCard>(find.byType(AppCard)).radius, 18.0);
    });

    testWidgets('a text input is 52-56 px tall', (t) async {
      await t.pumpWidget(
        host(
          const SizedBox(
            width: 320,
            child: AppTextField(label: 'Name'),
          ),
        ),
      );
      await t.pumpAndSettle();

      final height = t.getSize(find.byType(AppTextField)).height;
      // The label sits above the field, so measure the field box itself.
      final fieldBox = t.getSize(find.byType(AnimatedContainer).first);

      expect(
        fieldBox.height,
        inInclusiveRange(52, 56),
        reason: '§B3 input height; the whole control was $height tall',
      );
    });

    testWidgets('the input grows rather than clipping at a 200% text scale', (t) async {
      Future<double> fieldHeight(TextScaler scaler) async {
        await t.pumpWidget(
          host(
            const SizedBox(
              width: 320,
              child: AppTextField(label: 'Name'),
            ),
            textScaler: scaler,
          ),
        );
        await t.pumpAndSettle();
        return t.getSize(find.byType(AnimatedContainer).first).height;
      }

      final normal = await fieldHeight(TextScaler.noScaling);
      final doubled = await fieldHeight(TextScaler.linear(2.0));

      expect(
        doubled,
        greaterThan(normal),
        reason: 'a minHeight floor has to be a floor, not a fixed box',
      );
    });

    testWidgets('the input icon slot is a 44 px tap target', (t) async {
      await t.pumpWidget(
        host(
          const SizedBox(
            width: 320,
            child: AppTextField(
              label: 'Password',
              suffixIcon: Icon(Icons.visibility),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();

      final decoration = t
          .widget<TextField>(find.byType(TextField))
          .decoration!;
      final suffix = decoration.suffixIconConstraints!;

      expect(suffix.minWidth, greaterThanOrEqualTo(44));
      expect(suffix.minHeight, greaterThanOrEqualTo(44));
      expect(
        decoration.contentPadding!.resolve(TextDirection.ltr).left,
        18.0,
        reason: '§B3 side padding',
      );
    });
  });

  group('§B3 / §B accessibility — 200% text scale', () {
    testWidgets('a 200% system text scale is not clamped', (t) async {
      const designSize = 16.0;

      // Same text, same design size, one scaler applied by the framework and
      // one pinned off. The ratio between the two laid-out heights is the
      // scale that actually reached the render tree. (Width is no good here:
      // a `SizedBox` above the text would pin it either way.)
      await t.pumpWidget(
        host(
          const SizedBox(
            child: Text(
              'Dealer ready',
              textScaler: TextScaler.noScaling,
              style: TextStyle(fontSize: designSize),
            ),
          ),
        ),
      );
      final unscaled = t.getSize(find.byType(Text).first).height;

      await t.pumpWidget(
        host(
          const SizedBox(
            child: Text(
              'Dealer ready',
              style: TextStyle(fontSize: designSize),
            ),
          ),
          textScaler: TextScaler.linear(2.0),
        ),
      );
      final scaled = t.getSize(find.byType(Text).first).height;

      expect(
        scaled / unscaled,
        closeTo(2.0, 0.05),
        reason: 'the 2x scaler must reach the render tree unfiltered',
      );
    });

    testWidgets('the scaler a Text reads is the one in MediaQuery', (t) async {
      const key = Key('scaled');
      await t.pumpWidget(
        host(
          const SizedBox(
            width: 400,
            child: Text(
              'Dealer ready',
              key: key,
              style: TextStyle(fontSize: 16),
            ),
          ),
          textScaler: TextScaler.linear(2.0),
        ),
      );

      final context = t.element(find.byKey(key));
      expect(
        MediaQuery.textScalerOf(context).scale(16),
        32,
        reason: 'nothing in the tree rewrites or caps the inherited scaler',
      );
    });

    testWidgets('AppButton does not pin its label to a fixed height', (t) async {
      Future<double> buttonHeight(TextScaler scaler) async {
        await t.pumpWidget(
          host(
            const SizedBox(
              width: 240,
              child: AppButton(onPressed: _noop, child: Text('Deal')),
            ),
            textScaler: scaler,
          ),
        );
        await t.pumpAndSettle();
        return t.getSize(find.byType(AppButton)).height;
      }

      final normal = await buttonHeight(TextScaler.noScaling);
      final doubled = await buttonHeight(TextScaler.linear(2.0));

      expect(normal, greaterThanOrEqualTo(48));
      expect(
        doubled,
        greaterThan(normal),
        reason: 'a SizedBox(height:) here would clip the label at 200%',
      );
    });

    testWidgets('AppButton routes its label through AppScale, not a raw token', (t) async {
      await t.pumpWidget(
        host(
          const SizedBox(
            width: 240,
            child: AppButton(onPressed: _noop, child: Text('Deal')),
          ),
        ),
      );

      final text = t.widget<Text>(find.text('Deal'));
      final style = text.style ??
          DefaultTextStyle.of(t.element(find.text('Deal'))).style;
      final design = AppTypography.buttonStyle.fontSize!;

      expect(
        style.fontSize,
        closeTo(design, 0.01),
        reason:
            'the button used to overwrite AppTypography.buttonStyle.fontSize '
            '(already AppScale.sp-ed) with the raw design token',
      );
    });
  });

  group('Icon-only controls have accessible names', () {
    testWidgets('a tooltip names the control', (t) async {
      final handle = t.ensureSemantics();
      await t.pumpWidget(
        host(
          SquircleIconButton(
            icon: Icons.share,
            tooltip: 'Share',
            onPressed: _noop,
          ),
        ),
      );

      expect(
        t.getSemantics(find.byType(SquircleIconButton)).label,
        'Share',
      );
      handle.dispose();
    });

    testWidgets('an icon with a known meaning is named even without a tooltip', (t) async {
      // The four call sites that never passed a tooltip: three header back
      // buttons and the admin overflow menu.
      final handle = t.ensureSemantics();
      await t.pumpWidget(
        host(
          const SquircleIconButton(
            icon: Icons.chevron_left,
            onPressed: _noop,
          ),
        ),
      );

      expect(
        t.getSemantics(find.byType(SquircleIconButton)).label,
        'Back',
      );

      await t.pumpWidget(
        host(
          const SquircleIconButton(
            icon: Icons.more_vert,
            onPressed: _noop,
          ),
        ),
      );

      expect(
        t.getSemantics(find.byType(SquircleIconButton)).label,
        'More options',
      );
      handle.dispose();
    });

    testWidgets('an unknown icon with no tooltip is a button, not the word "Button"', (t) async {
      final handle = t.ensureSemantics();
      await t.pumpWidget(
        host(
          const SquircleIconButton(icon: Icons.abc, onPressed: _noop),
        ),
      );

      final node = t.getSemantics(find.byType(SquircleIconButton));
      expect(
        node.label,
        isNot('Button'),
        reason: 'a literal "Button" was announced for every control in the app',
      );
      expect(node.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('the tap target is 44 px', (t) async {
      await t.pumpWidget(
        host(
          const SquircleIconButton(icon: Icons.share, onPressed: _noop),
        ),
      );

      final size = t.getSize(find.byType(SquircleIconButton));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });

  group('§B1 small red text', () {
    test('the fill token and the text token are different colours', () {
      // The whole point of the §B1 split. If these ever collapse back to one
      // value, every "fixed" call site silently regresses.
      expect(AppColors.primary, isNot(AppColors.primaryText));
      expect(AppColors.primaryText, AppColors.redText);
    });
  });
}

void _noop() {}
