import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_divider.dart';
import '../../widgets/app_eyebrow.dart';
import '../../widgets/code_input.dart';
import '../../widgets/form_screen_header.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../../widgets/prompt_link.dart';

/// Unified join screen: enter an invite **code**, paste an invite **link**, or
/// scan a **QR code** — for games *and* groups, as a guest *or* signed in.
///
///  - Group code + signed in  → joins the group, opens it.
///  - Group code + guest       → prompts to sign in / create an account, then
///    lands on `/join-group?code=…` which completes the join.
///  - Game code (any user)     → opens the guest check-in flow.
///  - TV code (any user)       → opens the TV display.
///
/// Reachable at `/join` (public) from the landing page and from the signed-in
/// dashboard, and as the target of `/game/:code` deep links.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key, this.initialCode});

  /// Code lifted from a deep link (`/join?code=…` or `/game/…`). When present
  /// the screen resolves it automatically on open.
  final String? initialCode;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  /// When set, the entered code is a group invite but the visitor is a guest —
  /// the card swaps to a "sign in to join" call to action carrying this code.
  String? _groupSignInCode;

  @override
  void initState() {
    super.initState();
    final code = widget.initialCode?.trim() ?? '';
    if (code.isNotEmpty) {
      _controller.text = code;
      WidgetsBinding.instance.addPostFrameCallback((_) => _resolve(code));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _back() {
    final app = context.read<AppProvider>();
    final hasAccount = app.isAuthenticated && !app.isGuest;
    context.go(hasAccount ? RoutePaths.home : RoutePaths.landing);
  }

  Future<void> _scan() async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanQRScreen()),
    );
    if (!mounted || raw == null || raw.trim().isEmpty) return;
    _controller.text = raw.trim();
    _resolve(raw);
  }

  Future<void> _resolve(String raw) async {
    final input = raw.trim();
    if (input.isEmpty) {
      setState(() => _error = 'Enter an invite code or paste a link.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _groupSignInCode = null;
      _busy = true;
    });

    final app = context.read<AppProvider>();
    final res = await app.resolveJoinCode(input);
    if (!mounted) return;

    switch (res.kind) {
      case JoinCodeKind.notFound:
        _fail("We couldn't find that code. Check it and try again.");
      case JoinCodeKind.rateLimited:
        _fail('Too many attempts. Wait a minute and try again.');
      case JoinCodeKind.error:
        _fail('Something went wrong. Check your connection and try again.');

      case JoinCodeKind.group:
        // Anonymous guests must upgrade to a real account before joining a
        // group (group membership has no guest equivalent).
        if (app.isAuthenticated && !app.isGuest) {
          final ok = await app.joinGroup(res.code);
          if (!mounted) return;
          if (ok) {
            context.go(RoutePaths.members);
          } else {
            _fail("Couldn't join that group — the code may have changed.");
          }
        } else {
          setState(() {
            _busy = false;
            _groupSignInCode = res.code;
          });
        }

      case JoinCodeKind.game:
      case JoinCodeKind.tv:
        final look = await app.enterGameCode(res.code);
        if (!mounted) return;
        switch (look) {
          case CodeLookupResult.rateLimited:
            _fail('Too many attempts. Wait a minute and try again.');
          case CodeLookupResult.notFound:
            _fail("We couldn't find that game. Check the code and try again.");
          case CodeLookupResult.tv:
            context.go(RoutePaths.tvMode);
          case CodeLookupResult.game:
            if (!app.isAuthenticated) await app.ensureGuestAuth();
            if (!mounted) return;
            context.go(RoutePaths.guestFlow);
        }
    }
  }

  void _fail(String message) {
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  void _goSignIn(String path) {
    final next = Uri.encodeComponent(
      '${RoutePaths.joinGroup}?code=$_groupSignInCode',
    );
    context.go('$path?next=$next');
  }

  @override
  Widget build(BuildContext context) {
    final hasAccount = context.select<AppProvider, bool>(
      (a) => a.isAuthenticated && !a.isGuest,
    );

    return OnboardingScaffold(
      onBack: _back,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FormScreenHeader(
            centered: true,
            titleSize: 24,
            leading: IconTile(label: '♠', size: 52),
            title: 'Join a game or group',
            subtitle:
                'Enter an invite code, paste an invite link, or scan a QR '
                'code from your admin.',
          ),
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _groupSignInCode != null
                ? _buildSignInToJoin()
                : _buildInput(),
          ),
          const SizedBox(height: AppSpacing.md),
          if (!hasAccount && _groupSignInCode == null)
            PromptLink(
              prompt: 'Have an account? ',
              action: 'Sign in',
              onTap: () => context.go(RoutePaths.login),
            ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppEyebrow('Invite code or link', muted: true),
        const SizedBox(height: AppSpacing.sm),
        CodeInput(
          controller: _controller,
          semanticLabel: 'Invite code or link',
          autofocus: widget.initialCode == null,
          enabled: !_busy,
          hasError: _error != null,
          inputFormatters: [LengthLimitingTextInputFormatter(200)],
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: _resolve,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.destructiveText,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        AppButton(
          fullWidth: true,
          size: AppButtonSize.lg,
          loading: _busy,
          onPressed: _busy ? null : () => _resolve(_controller.text),
          child: const Text('Continue'),
        ),
        const AppDivider(label: 'OR', space: AppSpacing.xl),
        AppButton(
          fullWidth: true,
          size: AppButtonSize.lg,
          variant: AppButtonVariant.secondary,
          onPressed: _busy ? null : _scan,
          // The icon and label together want 220px; a 320px phone leaves the
          // button 164px inside its own padding. scaleDown shrinks the pair
          // to fit rather than clipping the label to "Scan QR c…", and does
          // nothing at any width where the label already fits.
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code_scanner, size: 18),
                SizedBox(width: AppSpacing.sm),
                Text('Scan QR code'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignInToJoin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppEyebrow('Group invite'),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Sign in to join this group',
          style: AppTypography.display(
            size: AppFontSizes.lg,
            weight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Joining a group needs a free account so your RSVPs, stats and chat '
          'stay with you. Sign in or create one — you\'ll join the group right '
          'after.',
          style: AppTypography.bodySm.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          fullWidth: true,
          size: AppButtonSize.lg,
          onPressed: () => _goSignIn(RoutePaths.login),
          child: const Text('Sign in to join'),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          fullWidth: true,
          size: AppButtonSize.lg,
          variant: AppButtonVariant.secondary,
          onPressed: () => _goSignIn(RoutePaths.register),
          child: const Text('Create free account'),
        ),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: InkWell(
            onTap: () => setState(() => _groupSignInCode = null),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 8,
              ),
              child: Text(
                'Use a different code',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-screen QR scanner. Pops the raw scanned payload (bare code or invite
/// URL) back to the caller, which resolves it through [AppProvider].
class ScanQRScreen extends StatefulWidget {
  const ScanQRScreen({super.key});

  @override
  State<ScanQRScreen> createState() => _ScanQRScreenState();
}

class _ScanQRScreenState extends State<ScanQRScreen> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: const Text('Scan invite QR'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
        elevation: 0,
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_handled) return;
              final code = capture.barcodes
                  .map((b) => b.rawValue)
                  .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
              if (code == null) return;
              _handled = true;
              Navigator.of(context).pop(code);
            },
          ),
          // Simple viewfinder framing.
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary, width: 3),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
          Positioned(
            bottom: 48,
            left: AppSpacing.xxl,
            right: AppSpacing.xxl,
            child: Text(
              'Point your camera at the invite QR code',
              textAlign: TextAlign.center,
              // This sits over the live camera feed, not over a themed
              // surface, so it cannot use a palette colour — the backdrop is
              // whatever the room looks like. Full white plus a drop shadow
              // instead of white70: 70% white vanishes against a bright wall.
              style: AppTypography.bodySm.copyWith(
                color: Colors.white,
                shadows: const [
                  Shadow(blurRadius: 4, color: Colors.black87),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
