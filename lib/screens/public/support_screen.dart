import 'package:flutter/material.dart';
import '../../app/typography.dart';
import '../../app/colors.dart';
import '../../widgets/app_button.dart';
import '../../constants/app_constants.dart';

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
          'host. Players see their position without anyone else\'s payouts.',
    ),
    (
      q: 'I found a bug. What do I do?',
      a:
          'Email support@pokernight.app with a short description of the problem and '
          'which screen you were on. Screenshots help us fix it faster.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Support', style: AppTypography.displaySm),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Need help?', style: AppTypography.display(size: 28)),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Search the answers below, or reach us any time at '
                  'support@pokernight.app — we usually reply within one business day.',
                  style: AppTypography.body(),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  'Frequently asked questions',
                  style: AppTypography.displaySm,
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final faq in _faqs) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(faq.q, style: AppTypography.bodyBold),
                        const SizedBox(height: AppSpacing.sm),
                        Text(faq.a, style: AppTypography.body()),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  onPressed: () => Navigator.of(context).pop(),
                  variant: AppButtonVariant.secondary,
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
