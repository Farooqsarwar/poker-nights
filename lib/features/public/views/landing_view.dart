import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pn_button.dart';
import '../../../core/widgets/pn_card.dart';

class LandingView extends StatefulWidget {
  const LandingView({super.key});

  @override
  State<LandingView> createState() => _LandingViewState();
}

class _LandingViewState extends State<LandingView> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;
            if (isWide) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: Center(child: _buildBranding())),
                      Expanded(child: Center(child: _buildContent(context))),
                    ],
                  ),
                ),
              );
            } else {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildBranding(),
                      const SizedBox(height: 32),
                      _buildContent(context),
                    ],
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildBranding() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: const BoxDecoration(
            color: AppColors.cardDark,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.style_rounded, size: 100, color: AppColors.primary)
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scaleXY(begin: 1.0, end: 1.08, duration: 2.seconds, curve: Curves.easeInOut),
        ),
        const SizedBox(height: 24),
        const Text('POKER NIGHT', textAlign: TextAlign.center, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: 8)),
      ],
    ).animate().fade(duration: 600.ms).scaleXY(begin: 0.95, end: 1.0, curve: Curves.easeOutCubic);
  }

  Widget _buildContent(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PNCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text('Join a Game', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'Enter 6-digit Code',
                    hintStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                      letterSpacing: 0,
                      fontWeight: FontWeight.normal,
                    ),
                    filled: true,
                    fillColor: AppColors.darkSurface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  maxLength: 6,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: PNButton(
                    label: 'Enter Game',
                    onPressed: () {
                      final code = _codeController.text.trim().toUpperCase();
                      if (code.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a game code')));
                        return;
                      }
                      context.push('/game/join/$code');
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => context.push('/login'),
                style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary, textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                child: const Text('Log In'),
              ),
              Container(width: 1, height: 16, margin: const EdgeInsets.symmetric(horizontal: 16), color: AppColors.textSecondary.withValues(alpha: 0.2)),
              TextButton(
                onPressed: () => context.push('/register'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary, textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                child: const Text('Create Account'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 24,
            runSpacing: 12,
            children: [
              _buildFooterLink('Privacy Policy', () => context.push('/privacy')),
              _buildFooterLink('Terms of Service', () => context.push('/terms')),
              _buildFooterLink('Contact / Support', () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Poker Night',
                  applicationVersion: '1.0.0',
                  applicationIcon: const Icon(Icons.style, size: 48, color: AppColors.primary),
                  children: [const Text('For support, contact your group administrator or email support@poker-night.app')],
                );
              }),
            ],
          ),
        ],
      ),
    ).animate().fade(duration: 600.ms, delay: 200.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildFooterLink(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
    );
  }
}

