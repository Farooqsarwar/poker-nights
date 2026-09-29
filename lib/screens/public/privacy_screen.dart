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

  // Draft wording that follows Build Spec D-H1; the final text is the lawyer's
  // (D13). It only states what the app really does today.
  static const _sections = <({String title, String body})>[
    (
      title: '1. What we collect',
      body:
          'Your name, email address and profile photo when you create an account, and '
          'what you create in the app: groups, games, results, chat messages and polls. '
          'Settings such as sound and display stay on your device.',
    ),
    (
      title: '2. How we use it',
      body:
          'To sign you in, run your games, keep your history and statistics, and send '
          'invitations and notifications. Past nights are used to improve blind '
          'structures only with your consent. We never sell your personal data and we '
          'do not use it for advertising profiles.',
    ),
    (
      title: '3. Groups and sharing',
      body:
          'Members of a group see the group\'s games, chat and standings. Everyone in a '
          'game sees the prize pool and the payouts. Your lifetime profit and loss and '
          'your money history are visible only to you. The host\'s organiser'
          'contribution is visible only to the host.',
    ),
    (
      title: '4. Game history that improves structures',
      body:
          'With your consent we keep bust times, the level at each bust and the final '
          'big blind for each game, per group. You agree at sign-up and can opt out for '
          'any group in its settings.',
    ),
    (
      title: '5. Your choices',
      body:
          'You can edit your profile, turn notifications off, export your data as JSON '
          'and delete your account, all from Settings. Deleting removes your account and '
          'personal data. Your finishes stay in your groups\' history as "Former member".',
    ),
    (
      title: '6. Where data is stored',
      body:
          'Your data is stored with Firebase (Google Cloud) so your group can see the '
          'same game on every phone. Some game state is also kept on your device so a '
          'game can be recovered offline. If we add usage analytics or crash reports, '
          'we will list them here first and ask before switching them on where the law '
          'requires it.',
    ),
    (
      title: '7. How long we keep it',
      body:
          'Game data and chat are kept while the group exists. When you delete your '
          'account, your personal data is removed as described above.',
    ),
    (
      title: '8. Children',
      body:
          'Poker Night is for adults (18+). We do not knowingly collect information '
          'from children. If you believe a child has given us information, contact us '
          'and we will delete it.',
    ),
    (
      title: '9. Contact',
      body:
          'Questions about this policy? Email support@pokernight.app and we will get '
          'back to you within one business day.',
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
