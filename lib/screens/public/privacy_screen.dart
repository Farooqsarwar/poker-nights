import 'package:flutter/material.dart';
import '../../app/typography.dart';
import '../../app/colors.dart';
import '../../constants/app_constants.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_eyebrow.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/legal_page.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _sections = <({String title, String body})>[
    (
      title: '1. Information we collect',
      body:
          'We collect the information you give us directly: your name, email address, '
          'and profile details when you create an account. We also collect tournament '
          'and cash-game data you create on the app, such as players, results, and chip '
          'counts. All of this data is stored locally on your device unless you choose '
          'to share it with your group.',
    ),
    (
      title: '2. How we use your information',
      body:
          'We use your information to run the app: signing you in, powering your game '
          'history and statistics, sending you game invitations and notifications, and '
          'improving the product. We never sell your personal information to third parties.',
    ),
    (
      title: '3. Groups and sharing',
      body:
          'When you join or create a group, members of that group can see the details of '
          'games hosted within it, including your name, results, and standing. Results '
          'and prize information for a tournament are visible only to the tournament '
          'admin unless the admin opts to publish them.',
    ),
    (
      title: '4. Data you can control',
      body:
          'You can update your name and email at any time from your profile, choose which '
          'notifications you receive from the Settings screen, and delete your account '
          'from Settings. Deleting your account removes your profile and personal game '
          'history from the app.',
    ),
    (
      title: '5. Data security',
      body:
          'We use industry-standard safeguards to protect your data. Game state is stored '
          'locally on your device for offline recovery, and nothing is transmitted to '
          'our servers without your action.',
    ),
    (
      title: '6. Children',
      body:
          'Poker Night is intended for adults. We do not knowingly collect information '
          'from children under 18. If you believe a child has provided us information, '
          'contact us and we will delete it.',
    ),
    (
      title: '7. Changes to this policy',
      body:
          'We may update this Privacy Policy from time to time. If we make material '
          'changes, we will notify you in the app before the changes take effect.',
    ),
    (
      title: '8. Contact',
      body:
          'Questions about this policy? Email support@pokernight.app and we will get '
          'back to you within 2 business days.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LegalPage(
      children: [
        const AppEyebrow('Effective date: August 1, 2026'),
        const SizedBox(height: AppSpacing.md),
        const LegalTitle('Privacy Policy'),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppTag('Overview', tone: AppTagTone.primary),
              const SizedBox(height: AppSpacing.md),
              Text(
                'This Privacy Policy explains what data Poker Night collects, how it is '
                'used, and the choices you have over your information.',
                style: AppTypography.body(height: 1.6),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        for (final s in _sections) ...[
          Text(
            s.title,
            style: AppTypography.body(
              size: AppFontSizes.md,
              weight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            s.body,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
              height: 1.65,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ],
    );
  }
}
