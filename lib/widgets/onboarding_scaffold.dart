import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../constants/app_constants.dart';
import '../responsive/responsive.dart';
import 'app_back_button.dart';

/// Page frame for the full-screen onboarding and access screens (auth, join,
/// guest flow): dark ground with a soft accent bloom from the top edge, an
/// optional back tile, a single readable column, and an optional [footer]
/// that sits at the bottom of the screen when there is room and simply
/// follows the content when there is not (small phones, keyboard open).
///
/// Mobile-first. On a wide viewport the same column is centred at
/// [maxWidth]; if an [aside] is given it fills the left half (brand panel),
/// which is the responsive web version of the phone layout rather than a
/// different design.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.child,
    this.footer,
    this.onBack,
    this.backTooltip = 'Back',
    this.aside,
    this.maxWidth = 420,
  });

  final Widget child;
  final Widget? footer;
  final VoidCallback? onBack;
  final String backTooltip;
  final Widget? aside;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width <= AppBreakpoints.tablet;
    final twoColumn = aside != null && width >= AppBreakpoints.desktop;
    final hPad = isMobile ? AppSpacing.lg : AppSpacing.xl;

    // heightFactor: 1 — centre horizontally only; a bare Center would expand
    // to the full height it is offered and float the footer mid-screen.
    Widget constrained(Widget w) => Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: w,
      ),
    );

    final column = CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            hPad,
            AppSpacing.sm,
            hPad,
            AppSpacing.lg,
          ),
          sliver: SliverToBoxAdapter(
            child: constrained(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (onBack != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      // Pull the 44px target's inner padding back to the
                      // gutter so the visible tile lines up with content.
                      child: Transform.translate(
                        offset: const Offset(-4, 0),
                        child: AppBackButton(
                          onTap: onBack!,
                          tooltip: backTooltip,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    // Phones start right under the back tile, as drawn; on a
                    // wide screen the column drops into the upper third
                    // instead of hugging the top edge.
                    height: isMobile
                        ? AppSpacing.lg
                        : (MediaQuery.sizeOf(context).height * 0.08)
                            .clamp(AppSpacing.xxl, 96.0),
                  ),
                  child,
                ],
              ),
            ),
          ),
        ),
        if (footer != null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 0, hPad, AppSpacing.md),
                child: constrained(footer!),
              ),
            ),
          ),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.topGlow),
        child: SafeArea(
          child: twoColumn
              ? Row(
                  children: [
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: AppColors.border.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        child: Center(child: aside),
                      ),
                    ),
                    Expanded(child: column),
                  ],
                )
              : column,
        ),
      ),
    );
  }
}
