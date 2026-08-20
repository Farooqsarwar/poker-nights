import 'package:flutter/material.dart';
import '../../app/typography.dart';
import '../../app/colors.dart';
import '../../constants/app_constants.dart';

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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Terms of Service', style: AppTypography.displaySm),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Effective date: August 1, 2026',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'These Terms of Service govern your access to and use of Poker Night.',
                  style: AppTypography.body(),
                ),
                const SizedBox(height: AppSpacing.xl),
                for (final s in _sections) ...[
                  Text(s.title, style: AppTypography.bodyBold),
                  const SizedBox(height: AppSpacing.sm),
                  Text(s.body, style: AppTypography.body()),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
