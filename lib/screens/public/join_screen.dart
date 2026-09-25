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
import '../../responsive/responsive.dart';
import '../../widgets/app_button.dart';
import '../../widgets/backgrounds.dart';
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
    final raw = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const ScanQRScreen()));
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

    final device = AppBreakpoints.deviceOf(context);
    final twoColumn = device.isDesktop || device.isLargeDesktop;
    final statusBarHeight = MediaQuery.paddingOf(context).top;

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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          FeltBackground(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                  vertical: twoColumn
                      ? AppSpacing.xl
                      : (statusBarHeight + AppSpacing.xxxl + 20),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: content,
                  ),
                ),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'INVITE CODE OR LINK',
          style: TextStyle(
            color: Color(0xFF9A9AA6),
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF26262A)),
          ),
          alignment: Alignment.center,
          child: TextField(
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
            style: const TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
              color: Colors.white,
            ),
            decoration: const InputDecoration(
              counterText: '',
              hintText: 'CODE',
              hintStyle: TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 18,
                letterSpacing: 3,
                color: Color(0xFF9A9AA6),
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFE5797A), fontSize: 12),
          ),
        ],
        const SizedBox(height: 20),
        Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66D53032),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD53032),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _busy ? null : () => _resolve(_controller.text),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Continue',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: const [
            Expanded(child: Divider(color: Color(0xFF242428))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OR',
                style: TextStyle(
                  color: Color(0xFF9A9AA6),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(child: Divider(color: Color(0xFF242428))),
          ],
        ),
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
                Text(
                  'Scan QR code',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
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
                  .firstWhere(
                    (v) => v != null && v.isNotEmpty,
                    orElse: () => null,
                  );
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
                shadows: const [Shadow(blurRadius: 4, color: Colors.black87)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
