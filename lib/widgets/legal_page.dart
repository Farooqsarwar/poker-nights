import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../responsive/responsive.dart';
import 'app_back_button.dart';

/// Frame for the calm long-form pages (privacy, terms, support): the dark
/// ground, a back tile, one readable column capped at 720px, and the page's
/// own content below.
///
/// Back behaviour: with [onBack] the tile always shows and calls it. Without
/// it the tile shows only when there is a route to pop, and pops it — the
/// same rule the default app-bar back arrow these pages used to have
/// followed, so no new way out is added.
class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.children, this.onBack});

  final List<Widget> children;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    final VoidCallback? back =
        onBack ?? (canPop ? () => Navigator.of(context).maybePop() : null);
    final hPad = AppBreakpoints.deviceOf(context).isMobile
        ? AppSpacing.lg
        : AppSpacing.xxl;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(hPad, AppSpacing.sm, hPad, AppSpacing.huge),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (back != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Transform.translate(
                        offset: const Offset(-4, 0),
                        child: AppBackButton(onTap: back, tooltip: 'Back'),
                      ),
                    )
                  else
                    const SizedBox(height: AppSpacing.lg),
                  const SizedBox(height: AppSpacing.lg),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Large page title for [LegalPage].
class LegalTitle extends StatelessWidget {
  const LegalTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.display(
        size: 28,
        weight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.6,
      ),
    );
  }
}
