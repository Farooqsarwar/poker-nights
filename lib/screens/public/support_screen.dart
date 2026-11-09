import 'package:flutter/foundation.dart' show defaultTargetPlatform;
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
          'Tap "Start a game now" for tonight, or "New tournament" to plan one: pick '
          'the date, the finish time and your chips; the app builds the blinds, the '
          'payouts and the schedule.',
    ),
    (
      q: 'Lost my game mid-way — recoverable?',
      a:
          'Yes. The running game is saved on the phone that runs the clock and synced '
          'to your group; open the app and tap Resume.',
    ),
    (
      q: 'Can I track cash games too?',
      a:
          'Yes — buy-ins, top-ups and cash-outs, and the fewest payments to settle at '
          'the end.',
    ),
    (
      q: 'Who sees the prizes?',
      a:
          'Everyone in the game sees the prize pool and the payouts. Only the host '
          'sees the organiser contribution, if one is set.',
    ),
    (
      q: 'Is this gambling?',
      a:
          'Poker Night doesn\'t take bets or move money. It is a clock and a '
          'calculator for your own game. Check the rules where you play.',
    ),
    (
      q: 'How do I report an abusive message?',
      a:
          'Press and hold the message and tap Report. The group\'s host is told; if '
          'nothing happens within a day, we are too. You can also Block someone to '
          'hide their messages.',
    ),
    (
      q: 'I found a bug. What do I do?',
      a:
          'Email support@pokernight.app with a short description of the problem and '
          'which screen you were on. Screenshots help us fix it faster.',
    ),
  ];

  Future<void> _emailSupport() async {
    // H3: the platform is pre-filled where the person can read and edit it
    // before sending; nothing personal is added behind their back.
    final body = 'Platform: ${defaultTargetPlatform.name}\n\n'
        'What happened:\n';
    final uri = Uri.parse(
      'mailto:$_supportEmail'
      '?subject=${Uri.encodeComponent('Poker Night support')}'
      '&body=${Uri.encodeComponent(body)}',
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
