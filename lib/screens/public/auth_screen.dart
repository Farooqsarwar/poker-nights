import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_divider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/brand_lockup.dart';
import '../../widgets/form_screen_header.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../../widgets/prompt_link.dart';

enum AuthMode { login, register, forgotPassword }

enum _Field { name, email, password, confirm }

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

  /// Which input a validation [_error] belongs to, so it renders inline under
  /// that field. Null for errors that are not about one field (auth/network).
  _Field? _errorField;
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

  void _fieldError(_Field field, String message) {
    setState(() {
      _error = message;
      _errorField = field;
    });
  }

  /// Clears an inline error once the user edits the field it points at.
  void _onEdited(_Field field) {
    if (_errorField == field) {
      setState(() {
        _error = null;
        _errorField = null;
      });
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _error = null;
      _errorField = null;
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
      _errorField = null;
      _success = null;
    });

    final email = _emailController.text.trim();
    final emailOk = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);

    if (!emailOk) {
      _fieldError(_Field.email, 'Enter a valid email address.');
      return;
    }

    if (!_isForgot && _passwordController.text.length < 8) {
      _fieldError(_Field.password, 'Password must be at least 8 characters.');
      return;
    }

    if (_isRegister && _nameController.text.trim().length < 2) {
      _fieldError(_Field.name, 'Name must be at least 2 characters.');
      return;
    }

    if (_isRegister && _confirmController.text != _passwordController.text) {
      _fieldError(_Field.confirm, 'Passwords do not match.');
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

  /// A trailing field icon, inset to sit inside the input.
  Widget _trailing(IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md, left: AppSpacing.sm),
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

  String? _errorFor(_Field field) => _errorField == field ? _error : null;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      onBack: () => context.go(RoutePaths.landing),
      // Wide web viewports keep the brand panel beside the form.
      aside: const PokerNightLogo(size: 200),
      footer: _isForgot ? null : _buildSwitchLine(),
      child: _buildForm()
          .animate()
          .fadeIn(duration: 400.ms)
          .slideY(begin: 0.04, end: 0, curve: Curves.easeOut),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormScreenHeader(
          title: _title,
          subtitle: _isForgot
              ? "Enter your email and we'll send a link to set a new one."
              : null,
        ),
        const SizedBox(height: AppSpacing.xl),
        // Google Sign-In — shown on login & register, not on
        // forgot-password (which is email-only by nature).
        if (!_isForgot) ...[
          _GoogleSignInButton(
            loading: _loading,
            onPressed: _handleGoogleSignIn,
          ),
          const AppDivider(
            label: 'or continue with email',
            space: AppSpacing.xl,
          ),
        ],
        if (_isRegister) ...[
          AppTextField(
            controller: _nameController,
            placeholder: 'Full Name',
            textCapitalization: TextCapitalization.words,
            suffixIcon: _trailing(Icons.person_outline),
            error: _errorFor(_Field.name),
            onChanged: (_) => _onEdited(_Field.name),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        AppTextField(
          controller: _emailController,
          placeholder: 'Email address',
          keyboardType: TextInputType.emailAddress,
          suffixIcon: _trailing(Icons.mail_outline),
          error: _errorFor(_Field.email),
          onChanged: (_) => _onEdited(_Field.email),
        ),
        if (!_isForgot) ...[
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _passwordController,
            placeholder: 'Password',
            obscureText: !_showPw,
            suffixIcon: _eyeToggle(),
            error: _errorFor(_Field.password),
            onChanged: (_) => _onEdited(_Field.password),
          ),
          if (_isRegister) ...[
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _confirmController,
              placeholder: 'Confirm Password',
              obscureText: !_showPw,
              suffixIcon: _eyeToggle(),
              error: _errorFor(_Field.confirm),
              onChanged: (_) => _onEdited(_Field.confirm),
            ),
          ],
        ],
        if (widget.mode == AuthMode.login)
          Align(
            alignment: Alignment.centerRight,
            child: PromptLink(
              action: 'Forgot Password?',
              bold: false,
              onTap: () => context.go(RoutePaths.forgotPassword),
            ),
          )
        else
          const SizedBox(height: AppSpacing.lg),
        // Errors that are not about one field (auth, network, provider).
        if (_error != null && _errorField == null) ...[
          _StatusLine(message: _error!, success: false),
          const SizedBox(height: AppSpacing.md),
        ],
        if (_success != null) ...[
          _StatusLine(message: _success!, success: true),
          const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.xs),
        // Solid white submit, as drawn on A3/A4/A5.
        AppButton(
          variant: AppButtonVariant.light,
          size: AppButtonSize.lg,
          fullWidth: true,
          loading: _loading,
          onPressed: _loading ? null : _handleSubmit,
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
        if (_isForgot) ...[
          const SizedBox(height: AppSpacing.md),
          PromptLink(
            action: 'Back to Sign In',
            onTap: () => context.go(RoutePaths.login),
          ),
        ],
      ],
    );
  }

  Widget _buildSwitchLine() {
    if (widget.mode == AuthMode.login) {
      return PromptLink(
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
      );
    }
    return PromptLink(
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
    );
  }
}

/// A form-level outcome line: auth/network failures in crimson, the
/// reset-link confirmation in green. Field validation renders inline under
/// its own input instead.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.message, required this.success});

  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final fg = success ? AppColors.successText : AppColors.destructiveText;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: success ? AppColors.successSoft : AppColors.destructiveSoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: success
                ? AppColors.successSoftBorder
                : AppColors.destructive.withValues(alpha: 0.30),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                success ? Icons.check_circle_outline : Icons.error_outline,
                size: 16,
                color: fg,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodySm.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A full-width "Continue with Google" button using the official Google "G"
/// logo asset (assets/google_logo.png), on the secondary dark surface.
class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.onPressed, this.loading = false});

  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      variant: AppButtonVariant.secondary,
      size: AppButtonSize.lg,
      fullWidth: true,
      loading: loading,
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Official Google "G" logo asset.
          Image.asset(
            'assets/google_logo.png',
            width: 18,
            height: 18,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(width: AppSpacing.md),
          const Flexible(
            child: Text(
              'Continue with Google',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
