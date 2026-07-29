import 'package:flutter/material.dart';
import 'package:poker_night/core/theme/app_colors.dart';
import 'package:poker_night/core/widgets/pn_card.dart';

class PrivacyView extends StatelessWidget {
  const PrivacyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      appBar: AppBar(
        title: const Text('Privacy Policy'),
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
                  Text('Privacy Policy', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  SizedBox(height: 16),
                  Text('Last Updated: July 2026', style: TextStyle(color: AppColors.textSecondary)),
                  SizedBox(height: 32),
                  Text('1. Information We Collect', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  SizedBox(height: 8),
                  Text('Poker Night collects minimal personal information required to operate the service, including your name, email address, and game preferences. All data is stored locally on your device by default.', style: TextStyle(color: AppColors.textSecondary, height: 1.6)),
                  SizedBox(height: 24),
                  Text('2. How We Use Information', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  SizedBox(height: 8),
                  Text('We use your information solely to provide tournament management features, facilitate group interactions, and improve the application experience.', style: TextStyle(color: AppColors.textSecondary, height: 1.6)),
                  SizedBox(height: 24),
                  Text('3. Data Storage', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  SizedBox(height: 8),
                  Text('By default, all game data is stored locally on your device. When cloud sync is enabled, data is encrypted in transit and at rest.', style: TextStyle(color: AppColors.textSecondary, height: 1.6)),
                  SizedBox(height: 24),
                  Text('4. Third-Party Services', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  SizedBox(height: 8),
                  Text('Poker Night does not share your data with third parties. Optional cloud sync uses Supabase, which adheres to industry-standard security practices.', style: TextStyle(color: AppColors.textSecondary, height: 1.6)),
                  SizedBox(height: 24),
                  Text('5. Contact', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  SizedBox(height: 8),
                  Text('For privacy inquiries, contact the group administrator who invited you to Poker Night.', style: TextStyle(color: AppColors.textSecondary, height: 1.6)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
