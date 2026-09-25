import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../../responsive/responsive.dart';
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

  Widget _trailing(IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: Icon(icon, size: 20, color: const Color(0xFF9A9AA6)),
    );
  }

  /// The trailing eye toggle shared by password / confirm fields.
  Widget _eyeToggle() {
    return IconButton(
      icon: Icon(
        _showPw ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 20,
        color: const Color(0xFF9A9AA6),
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

    final statusBarHeight = MediaQuery.paddingOf(context).top;
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
                      padding: EdgeInsets.only(
                        left: AppSpacing.lg,
                        right: AppSpacing.lg,
                        top: statusBarHeight + AppSpacing.xxxl + 20,
                        bottom: AppSpacing.huge,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [card],
                      ),
                    ),
                  ),
            Positioned(
              top: statusBarHeight + AppSpacing.md,
              left: AppSpacing.lg,
              child: Semantics(
                button: true,
                label: 'Back',
                child: InkWell(
                  onTap: () => context.go(RoutePaths.landing),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF141416),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF242428)),
                    ),
                    child: const Icon(
                      Icons.chevron_left,
                      size: 22,
                      color: Color(0xFFE5797A),
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
    final device = AppBreakpoints.deviceOf(context);
    final twoColumn = device.isDesktop || device.isLargeDesktop;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _title,
          style: AppTypography.display(
            size: AppFontSizes.xxl,
            weight: FontWeight.w700,
          ),
        ),
        if (_isForgot) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            "Enter your email and we'll send a link to set a new one.",
            style: const TextStyle(
              color: Color(0xFFB8B8C2),
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ],
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
            children: const [
              Expanded(child: Divider(color: Color(0xFF242428))),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  'or continue with email',
                  style: TextStyle(color: Color(0xFF9A9AA6), fontSize: 12),
                ),
              ),
              Expanded(child: Divider(color: Color(0xFF242428))),
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
            suffixIcon: _trailing(Icons.person_outline),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        AppTextField(
          controller: _emailController,
          label: null,
          placeholder: 'Email address',
          keyboardType: TextInputType.emailAddress,
          suffixIcon: _trailing(Icons.mail_outline),
        ),
        if (!_isForgot) ...[
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _passwordController,
            label: null,
            placeholder: 'Password',
            obscureText: !_showPw,
            suffixIcon: _eyeToggle(),
          ),
          if (_isRegister) ...[
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _confirmController,
              label: null,
              placeholder: 'Confirm Password',
              obscureText: !_showPw,
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
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: Color(0xFFE5797A),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
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
              color: AppColors.destructiveText,
            ),
          ),
        ],
        if (_success != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            _success!,
            style: AppTypography.bodySm.copyWith(color: AppColors.successText),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0A0A0A),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _loading ? null : _handleSubmit,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF0A0A0A),
                    ),
                  )
                : Text(
                    _isForgot
                        ? 'Send reset link'
                        : _isRegister
                        ? 'Create Account'
                        : 'Sign In',
                    style: const TextStyle(
                      color: Color(0xFF0A0A0A),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (widget.mode == AuthMode.login) ...[
          _switchLine(
            context,
            prompt: "Don't have an account? ",
            action: 'Create Account',
            onTap: () {
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
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Text(
                  'Back to Sign In',
                  style: TextStyle(
                    color: Color(0xFFE5797A),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: twoColumn
          ? Container(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.cardGlow,
              ),
              child: content,
            )
          : Container(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: content,
            ),
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
              style: const TextStyle(color: Color(0xFF9A9AA6), fontSize: 13),
            ),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  child: Text(
                    action,
                    style: const TextStyle(
                      color: Color(0xFFE5797A),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
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
