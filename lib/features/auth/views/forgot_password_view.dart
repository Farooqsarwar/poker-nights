import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/core/theme/app_colors.dart';
import 'package:poker_night/core/widgets/pn_button.dart';
import 'package:poker_night/core/widgets/pn_text_field.dart';
import 'package:poker_night/core/widgets/pn_card.dart';
import 'package:poker_night/features/auth/controllers/auth_controller.dart';

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitted = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: AppColors.cardDark,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;
          
          Widget content = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: PNCard(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.lock_reset, size: 64, color: AppColors.primary),
                    const SizedBox(height: 24),
                    const Text(
                      'Forgot your password?',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter your email address and we\'ll send you a link to reset your password.',
                      style: TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    PNTextField(
                      controller: _emailController,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter your email';
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    if (_isSubmitted)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: const Text(
                          'If an account exists for this email, you will receive a password reset link shortly.',
                          style: TextStyle(color: Colors.green),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      PNButton(
                        label: 'Send Reset Link',
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            await Get.find<AuthController>()
                                .sendPasswordReset(_emailController.text);
                            setState(() => _isSubmitted = true);
                          }
                        },
                      ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Back to Login', style: TextStyle(color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
            ),
          );

          if (isWide) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(48),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(child: Center(child: content)),
                  ],
                ),
              ),
            );
          } else {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: content,
              ),
            );
          }
        },
      ),
    );
  }
}
