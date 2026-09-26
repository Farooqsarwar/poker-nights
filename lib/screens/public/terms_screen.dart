import 'package:flutter/material.dart';
import '../../app/typography.dart';
import '../../app/colors.dart';
import '../../constants/app_constants.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_eyebrow.dart';
import '../../widgets/legal_page.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static const _sections = <({String title, String body})>[
    (
      title: '1. Your use of Poker Night',
      body:
          'By using Poker Night you agree to these Terms of Service. You must be at '
          'least 18 years old to create an account. You are responsible for the accuracy '
          'of the information you provide and for keeping your sign-in details secure.',
    ),
    (
      title: '2. The service',
      body:
          'Poker Night is a tool for organising home poker games: tournaments, cash '
          'games, player check-ins, chip counts, and results. It is provided "as is" '
          'and "as available". We do not facilitate or encourage real-money gambling '
          'where it is not lawful to do so; any wagering between players is a matter '
          'for the players themselves.',
    ),
    (
      title: '3. Your data',
      body:
          'You own the data you enter into the app. You grant us a non-exclusive, '
          'revocable licence to process that data solely to operate and improve the '
          'service. You may delete your account and data at any time from Settings.',
    ),
    (
      title: '4. Acceptable use',
      body:
          'You agree not to misuse the service, attempt to access it through unauthorised '
          'means, interfere with other users, or use it to run games where participation '
          'is not lawful. We may suspend accounts that breach these terms.',
    ),
    (
      title: '5. Intellectual property',
      body:
          'The Poker Night name, logo, and interface are protected by copyright and '
          'trademark law. You may not copy, modify, or distribute them without our '
          'written permission.',
    ),
    (
      title: '6. Disclaimers and liability',
      body:
          'To the maximum extent permitted by law, Poker Night and its makers are not '
          'liable for indirect, incidental, or consequential damages arising from your '
          'use of the service. Our total liability for any claim is limited to the '
          'amount you paid us in the 12 months before the claim.',
    ),
    (
      title: '7. Changes to these terms',
      body:
          'We may update these Terms from time to time. Material changes will be '
          'announced in the app. Continued use after changes take effect means you '
          'accept the updated terms.',
    ),
    (
      title: '8. Contact',
      body: 'Questions about these Terms? Email support@pokernight.app.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LegalPage(
      children: [
        const AppEyebrow('Effective date: August 1, 2026'),
        const SizedBox(height: AppSpacing.md),
        const LegalTitle('Terms of Service'),
        const SizedBox(height: AppSpacing.md),
        Text(
          'These Terms of Service govern your access to and use of Poker Night.',
          style: AppTypography.bodySm.copyWith(
            color: AppColors.mutedForeground,
            height: 1.6,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        for (final s in _sections) ...[
          _TermCard(title: s.title, body: s.body),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

/// One numbered term as the H2 frame draws it: the number large and crimson,
/// then the heading and body. The number is split off the existing
/// "1. Heading" titles, so the copy itself is unchanged.
class _TermCard extends StatelessWidget {
  const _TermCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final match = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(title);
    final number = match?.group(1);
    final heading = match?.group(2) ?? title;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (number != null) ...[
            SizedBox(
              width: 28,
              child: Text(
                number,
                style: AppTypography.mono(
                  size: AppFontSizes.xl,
                  weight: FontWeight.w700,
                  color: AppColors.primaryText,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading,
                  style: AppTypography.body(
                    size: AppFontSizes.md,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  body,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.mutedForeground,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
