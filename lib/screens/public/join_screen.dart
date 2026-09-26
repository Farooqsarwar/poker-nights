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
<<<<<<< Updated upstream
import '../../widgets/app_card.dart';
import '../../widgets/backgrounds.dart';
=======
>>>>>>> Stashed changes
import '../../widgets/brand_lockup.dart';

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

<<<<<<< Updated upstream
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FeltBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl,
              vertical: AppSpacing.xl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _BackLink(onTap: _back),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Center(child: PokerNightLogo(size: 64)),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Join a game or group',
                      textAlign: TextAlign.center,
                      style: AppTypography.display(size: AppFontSizes.xxl),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Enter an invite code, paste an invite link, or scan a QR '
                      'code from your admin.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: _groupSignInCode != null
                          ? _buildSignInToJoin()
                          : _buildInput(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (!hasAccount && _groupSignInCode == null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Have an account? ',
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                          InkWell(
                            onTap: () => context.go(RoutePaths.login),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              child: Text(
                                'Sign in',
                                style: AppTypography.bodySm.copyWith(
                                  color: AppColors.primary,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
=======
    final device = AppBreakpoints.deviceOf(context);
    final twoColumn = device.isDesktop || device.isLargeDesktop;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (twoColumn) ...[
          const Center(child: PokerNightLogo(size: 64)),
          const SizedBox(height: AppSpacing.lg),
        ] else ...[
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFD53032),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66D53032),
                    blurRadius: 18,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                '♠',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          'Join a game or group',
          textAlign: TextAlign.center,
          style: AppTypography.display(
            size: 22,
            weight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Enter an invite code, paste an invite link, or\nscan a QR code from your admin.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFB8B8C2),
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF242428)),
          ),
          child: _groupSignInCode != null
              ? _buildSignInToJoin()
              : _buildInput(),
        ),
        const SizedBox(height: 24),
        if (!hasAccount && _groupSignInCode == null)
          Center(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Have an account? ',
                    style: TextStyle(color: Color(0xFF9A9AA6), fontSize: 13),
                  ),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: InkWell(
                      onTap: () => context.go(RoutePaths.login),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Text(
                          'Sign in',
                          style: TextStyle(
                            color: Color(0xFFE5797A),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: Color(0xFFE5797A),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    final backBtn = Semantics(
      button: true,
      label: 'Back',
      child: InkWell(
        onTap: _back,
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
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: twoColumn
            ? Row(
                children: [
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            backBtn,
                            const SizedBox(height: 24),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: content,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: backBtn,
                      ),
                      const SizedBox(height: 24),
                      content,
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
>>>>>>> Stashed changes
      ),
    );
  }

  Widget _buildInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Invite code or link',
          style: AppTypography.bodySm.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _controller,
          autofocus: widget.initialCode == null,
          enabled: !_busy,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: _resolve,
          inputFormatters: [LengthLimitingTextInputFormatter(200)],
          style: AppTypography.monoLg.copyWith(letterSpacing: 2),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'CODE',
            hintStyle: AppTypography.monoLg.copyWith(
              color: AppColors.onSurfaceHint,
              letterSpacing: 2,
            ),
            isDense: true,
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: AppColors.ring),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: AppTypography.bodyXs.copyWith(color: AppColors.destructive),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          fullWidth: true,
          size: AppButtonSize.lg,
          loading: _busy,
          onPressed: () => _resolve(_controller.text),
          child: const Text('Continue'),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(child: Divider(color: AppColors.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                'OR',
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
            Expanded(child: Divider(color: AppColors.border)),
          ],
        ),
<<<<<<< Updated upstream
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          fullWidth: true,
          size: AppButtonSize.lg,
          variant: AppButtonVariant.secondary,
          onPressed: _busy ? null : _scan,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_scanner, size: 18),
              SizedBox(width: AppSpacing.sm),
              Text('Scan QR code'),
            ],
=======
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFF1E1E22),
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF28282C)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _busy ? null : _scan,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.qr_code_scanner, size: 20, color: Colors.white),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Scan QR code',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
>>>>>>> Stashed changes
          ),
        ),
      ],
    );
  }

  Widget _buildSignInToJoin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.groups_outlined, color: AppColors.primary, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Group invite',
                style: AppTypography.bodyLg.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
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
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: InkWell(
            onTap: () => setState(() => _groupSignInCode = null),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Text(
                'Use a different code',
                style: AppTypography.bodyXs.copyWith(
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

class _BackLink extends StatelessWidget {
  const _BackLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back, size: 16, color: AppColors.mutedForeground),
            const SizedBox(width: 6),
            Text(
              'Back',
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
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
              style: AppTypography.bodySm.copyWith(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
