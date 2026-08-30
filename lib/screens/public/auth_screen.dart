import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../repositories/firebase_repository.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../../responsive/responsive.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/backgrounds.dart';
import '../../widgets/brand_lockup.dart';

enum AuthMode { login, register, forgotPassword }

/// Auth screens (login / register / forgot password) mirroring `AuthPage`.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.mode, this.next});

  final AuthMode mode;

  /// Route to land on after a successful sign-in (e.g. the page the user was
  /// trying to reach before being sent to auth). Defaults to `/home`.
  final String? next;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  String? _error;
  String? _success;
  bool _loading = false;
  bool _showPw = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _isRegister => widget.mode == AuthMode.register;
  bool get _isForgot => widget.mode == AuthMode.forgotPassword;

  String get _title {
    switch (widget.mode) {
      case AuthMode.login:
        return 'Sign In';
      case AuthMode.register:
        return 'Create Account';
      case AuthMode.forgotPassword:
        return 'Reset Password';
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    final app = context.read<AppProvider>();
    final error = await app.loginWithGoogle();
    if (!mounted) return;
    setState(() => _loading = false);
    if (error == null) {
      // Success — router redirect will take over once auth state updates.
      context.go(widget.next ?? RoutePaths.home);
    } else if (error.isNotEmpty) {
      // Empty string == user cancelled; don't show an error.
      setState(() => _error = error);
    }
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _error = null;
      _success = null;
    });

    final email = _emailController.text.trim();
    final emailOk = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);

    if (!emailOk) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }

    if (!_isForgot && _passwordController.text.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }

    if (_isRegister && _nameController.text.trim().length < 2) {
      setState(() => _error = 'Name must be at least 2 characters.');
      return;
    }

    if (_isRegister && _confirmController.text != _passwordController.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() => _loading = true);
    final app = context.read<AppProvider>();

    final String? error;
    switch (widget.mode) {
      case AuthMode.login:
        error = await app.login(email, _passwordController.text);
      case AuthMode.register:
        error = await app.register(
          _nameController.text.trim(),
          email,
          _passwordController.text,
        );
      case AuthMode.forgotPassword:
        error = await app.requestPasswordReset(email);
    }
    if (!mounted) return;

    if (error != null) {
      setState(() {
        _loading = false;
        _error = error;
      });
      return;
    }

    if (_isForgot) {
      setState(() {
        _loading = false;
        _success = 'A password reset link has been sent to $email.';
      });
      return;
    }
    context.go(widget.next ?? RoutePaths.home);
  }

  /// A leading field icon padded to sit inside the input pill.
  Widget _leading(IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.sm),
      child: Icon(icon, size: 18, color: AppColors.mutedForeground),
    );
  }

  /// The trailing eye toggle shared by password / confirm fields.
  Widget _eyeToggle() {
    return IconButton(
      icon: Icon(
        _showPw ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 18,
        color: AppColors.mutedForeground,
      ),
      tooltip: _showPw ? 'Hide password' : 'Show password',
      onPressed: () => setState(() => _showPw = !_showPw),
    );
  }

  @override
  Widget build(BuildContext context) {
    final device = AppBreakpoints.deviceOf(context);
    final twoColumn = device.isDesktop || device.isLargeDesktop;

    final logo = const PokerNightLogo(size: 160);

    final card = _buildCard(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FeltBackground(
        child: Stack(
          children: [
            twoColumn
                ? Row(
                    children: [
                      Expanded(child: Center(child: logo)),
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(AppSpacing.xxl),
                            child: card,
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: AppSpacing.huge),
                          logo,
                          const SizedBox(height: AppSpacing.xxl),
                          card,
                          const SizedBox(height: AppSpacing.huge),
                        ],
                      ),
                    ),
                  ),
            Positioned(
              top: AppSpacing.xl,
              left: AppSpacing.xl,
              child: Semantics(
                button: true,
                label: 'Back',
                child: InkWell(
                  onTap: () => context.go(RoutePaths.landing),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_back,
                          size: 18,
                          color: AppColors.mutedForeground,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Back',
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child:
          Container(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.cardGlow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _title,
                      style: AppTypography.display(size: AppFontSizes.xxl),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    // Google Sign-In — shown on login & register, not on
                    // forgot-password (which is email-only by nature).
                    if (!_isForgot) ...[
                      _GoogleSignInButton(
                        loading: _loading,
                        onPressed: _handleGoogleSignIn,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(child: Divider(color: AppColors.border)),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            child: Text(
                              'or continue with email',
                              style: AppTypography.bodyXs.copyWith(
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: AppColors.border)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if (_isRegister) ...[
                      AppTextField(
                        controller: _nameController,
                        label: null,
                        placeholder: 'Full Name',
                        textCapitalization: TextCapitalization.words,
                        prefixIcon: _leading(Icons.person_outline),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    AppTextField(
                      controller: _emailController,
                      label: null,
                      placeholder: 'Email address',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: _leading(Icons.mail_outline),
                    ),
                    if (!_isForgot) ...[
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        controller: _passwordController,
                        label: null,
                        placeholder: 'Password',
                        obscureText: !_showPw,
                        prefixIcon: _leading(Icons.lock_outline),
                        suffixIcon: _eyeToggle(),
                      ),
                      if (_isRegister) ...[
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(
                          controller: _confirmController,
                          label: null,
                          placeholder: 'Confirm Password',
                          obscureText: !_showPw,
                          prefixIcon: _leading(Icons.lock_outline),
                          suffixIcon: _eyeToggle(),
                        ),
                      ],
                    ],
                    if (widget.mode == AuthMode.login) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: InkWell(
                          onTap: () => context.go(RoutePaths.forgotPassword),
                          child: Text(
                            'Forgot Password?',
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _error!,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.destructive,
                        ),
                      ),
                    ],
                    if (_success != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _success!,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      variant: AppButtonVariant.light,
                      size: AppButtonSize.lg,
                      fullWidth: true,
                      loading: _loading,
                      onPressed: _handleSubmit,
                      child: Text(
                        _loading
                            ? 'Please wait…'
                            : _isForgot
                            ? 'Send reset link'
                            : _isRegister
                            ? 'Create Account'
                            : 'Sign In',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (widget.mode == AuthMode.login) ...[
                      _switchLine(
                        context,
                        prompt: "Don't have an account? ",
                        action: 'Create Account',
                        onTap: () {
                          // Carry the deep-link destination through to the
                          // register screen so it isn't lost mid-flow (C2).
                          final next = widget.next;
                          if (next != null) {
                            context.go(
                              '${RoutePaths.register}?next=${Uri.encodeComponent(next)}',
                            );
                          } else {
                            context.go(RoutePaths.register);
                          }
                        },
                      ),
                    ] else if (_isRegister) ...[
                      _switchLine(
                        context,
                        prompt: 'Already have an account? ',
                        action: 'Sign In',
                        onTap: () {
                          final next = widget.next;
                          if (next != null) {
                            context.go(
                              '${RoutePaths.login}?next=${Uri.encodeComponent(next)}',
                            );
                          } else {
                            context.go(RoutePaths.login);
                          }
                        },
                      ),
                    ] else ...[
                      Center(
                        child: InkWell(
                          onTap: () => context.go(RoutePaths.login),
                          child: Text(
                            'Back to Sign In',
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              )
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
    );
  }

  Widget _switchLine(
    BuildContext context, {
    required String prompt,
    required String action,
    required VoidCallback onTap,
  }) {
    return Center(
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: prompt,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: InkWell(
                onTap: onTap,
                child: Text(
                  action,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// A full-width "Continue with Google" button using the official Google "G"
/// logo asset (assets/google_logo.png).
class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.onPressed, this.loading = false});

  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.border),
          backgroundColor: AppColors.card,
          foregroundColor: AppColors.foreground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.mutedForeground,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Official Google "G" logo asset.
                  Image.asset(
                    'assets/google_logo.png',
                    width: 20,
                    height: 20,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Continue with Google',
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
