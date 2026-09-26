import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_eyebrow.dart';
import '../../widgets/legal_page.dart';
import '../../constants/app_constants.dart';

const _supportEmail = 'support@pokernight.app';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  static const _faqs = <({String q, String a})>[
    (
      q: 'How do I start a tournament?',
      a:
          'Go to the Home screen and tap "Create Tournament". Choose a blind structure, '
          'pick a chip set, invite players, and you are ready to check in and deal.',
    ),
    (
      q: 'I lost my tournament mid-game — can I get it back?',
      a:
          'Yes. Poker Night saves your active tournament locally and restores it '
          'automatically the next time you open the app, right where you left off.',
    ),
    (
      q: 'Can I track cash games too?',
      a:
          'Absolutely. Start a cash game from the Home screen, track buy-ins and '
          'top-ups, and settle up at the end of the night.',
    ),
    (
      q: 'How are results kept private?',
      a:
          'Prize amounts and the full results table are only shown to the tournament '
          'admin. Players see their position without anyone else\'s payouts.',
    ),
    (
      q: 'I found a bug. What do I do?',
      a:
          'Email support@pokernight.app with a short description of the problem and '
          'which screen you were on. Screenshots help us fix it faster.',
    ),
  ];

  Future<void> _emailSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      query: 'subject=Poker Night support',
    );
    await launchUrl(uri);
  }

  void _back(BuildContext context) {
    if (GoRouter.of(context).canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LegalPage(
      onBack: () => _back(context),
      children: [
        const LegalTitle('Need help?'),
        const SizedBox(height: AppSpacing.md),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'Search the answers below, or reach us any time at ',
              ),
              TextSpan(
                text: _supportEmail,
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(
                text: ' — we usually reply within one business day.',
              ),
            ],
          ),
          style: AppTypography.bodySm.copyWith(
            color: AppColors.mutedForeground,
            height: 1.6,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const AppEyebrow('Frequently asked questions', muted: true),
        const SizedBox(height: AppSpacing.md),
        for (final faq in _faqs) ...[
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  faq.q,
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  faq.a,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.mutedForeground,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.md),
        // "Found a bug?" — the H3 closing card, carrying the Email us action.
        AppCard(
          color: AppColors.primarySoft,
          borderColor: AppColors.primary,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Found a bug?',
                      style: AppTypography.bodySm.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _supportEmail,
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              AppButton(
                onPressed: _emailSupport,
                size: AppButtonSize.sm,
                child: const Text('Email us'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          onPressed: () => _back(context),
          variant: AppButtonVariant.ghost,
          fullWidth: true,
          child: const Text('Back'),
        ),
      ],
    );
  }
}
