import 'package:flutter/material.dart';
import 'package:poker_night/core/theme/app_colors.dart';
import 'package:poker_night/core/widgets/pn_card.dart';

class TermsView extends StatelessWidget {
  const TermsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      appBar: AppBar(
        title: const Text('Terms of Service'),
        backgroundColor: AppColors.cardDark,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: PNCard(
              padding: const EdgeInsets.all(32),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Terms of Service', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  SizedBox(height: 16),
                  Text('Last Updated: July 2026', style: TextStyle(color: AppColors.textSecondary)),
                  SizedBox(height: 32),
                  Text('1. Acceptance of Terms', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  SizedBox(height: 8),
                  Text('By using Poker Night, you agree to these terms. If you do not agree, do not use the application.', style: TextStyle(color: AppColors.textSecondary, height: 1.6)),
                  SizedBox(height: 24),
                  Text('2. Description of Service', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  SizedBox(height: 8),
                  Text('Poker Night is a tournament and cash game management tool. It does not handle real-money transactions, card dealing, or gambling operations. All monetary values are for tracking purposes only.', style: TextStyle(color: AppColors.textSecondary, height: 1.6)),
                  SizedBox(height: 24),
                  Text('3. User Responsibilities', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  SizedBox(height: 8),
                  Text('Users are responsible for the accuracy of data entered. Organizers must ensure compliance with local laws regarding private poker games.', style: TextStyle(color: AppColors.textSecondary, height: 1.6)),
                  SizedBox(height: 24),
                  Text('4. Limitations', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  SizedBox(height: 8),
                  Text('Poker Night is provided "as is" without warranty. The developers are not liable for financial losses, data inaccuracies, or gameplay disputes.', style: TextStyle(color: AppColors.textSecondary, height: 1.6)),
                  SizedBox(height: 24),
                  Text('5. Changes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  SizedBox(height: 8),
                  Text('We reserve the right to update these terms. Continued use after changes constitutes acceptance.', style: TextStyle(color: AppColors.textSecondary, height: 1.6)),
                  SizedBox(height: 24),
                  Text('6. Contact', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  SizedBox(height: 8),
                  Text('For questions, contact your group administrator.', style: TextStyle(color: AppColors.textSecondary, height: 1.6)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
