import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/form_screen_header.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/prompt_link.dart';
import '../../widgets/stat_rows_card.dart';
import '../../widgets/app_toast.dart';

/// Landing page for a group invite link/QR code (`/join-group?code=...`).
/// Matches the A8 Join Group frame: group-invite tag, initials tile, group
/// name, inviter, a members / games-played summary, and the actions.
///
/// Opening the link only looks the group up (E6): the screen previews its
/// name, host, member count and games played, and nothing happens until the
/// person taps "Join group". "Not now" goes home without joining.
class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key, required this.code});

  final String code;

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

enum _JoinState { working, preview, joining, failure }

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  _JoinState _state = _JoinState.working;
  GroupInvitePreview? _preview;
  bool _joinFailed = false;

  String get _groupName => _preview?.name ?? '';

  int get _memberCount => _preview?.memberCount ?? 0;

  int? get _gamesCount => _preview?.gamesPlayed;

  String get _invitedBy {
    final host = _preview?.hostName;
    if (host != null && host.isNotEmpty) return 'Invited by $host';
    return 'You\'ve been invited to join';
  }

  String get _groupInitials {
    final name = _groupName;
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '♠';
    return parts
        .map((p) => p[0].toUpperCase())
        .join()
        .substring(0, parts.length >= 2 ? 2 : 1);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPreview());
  }

  Future<void> _loadPreview() async {
    final preview =
        await context.read<AppProvider>().previewInvite(widget.code);
    if (!mounted) return;
    setState(() {
      _preview = preview;
      _state = preview == null ? _JoinState.failure : _JoinState.preview;
    });
  }

  Future<void> _join() async {
    final app = context.read<AppProvider>();
    final router = GoRouter.of(context);
    // Signed out: previewing was free, joining needs an account. Register (or
    // sign in) and come straight back to this invite.
    if (!app.isAuthenticated) {
      final next = Uri.encodeComponent(
        '${RoutePaths.joinGroup}?code=${Uri.encodeComponent(widget.code)}',
      );
      router.go('${RoutePaths.register}?next=$next');
      return;
    }
    setState(() {
      _state = _JoinState.joining;
      _joinFailed = false;
    });
    final ok = await app.joinGroup(widget.code);
    if (!mounted) return;
    if (ok) {
      AppToast.show(context, "You're in");
      router.go(RoutePaths.home);
    } else {
      setState(() {
        _state = _JoinState.preview;
        _joinFailed = true;
      });
    }
  }

  void _leave() {
    final signedIn = context.read<AppProvider>().isAuthenticated;
    context.go(signedIn ? RoutePaths.home : RoutePaths.landing);
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      maxWidth: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: const Offset(-4, 0),
              child: AppBackButton(
                onTap: _leave,
                tooltip: 'Back',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          switch (_state) {
            _JoinState.working => _buildWorking(),
            _JoinState.failure => _buildFailure(),
            _JoinState.preview || _JoinState.joining => _buildInvite(),
          },
        ],
      ),
    );
  }

  Widget _buildWorking() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.huge),
      child: Semantics(
        liveRegion: true,
        child: FormScreenHeader(
          centered: true,
          titleSize: AppFontSizes.lg,
          leading: IconTile(
            size: 56,
            tone: IconTileTone.soft,
            semanticLabel: 'Loading',
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primaryText,
              ),
            ),
          ),
          title: 'Checking invitation…',
        ),
      ),
    );
  }

  Widget _buildFailure() {
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FormScreenHeader(
            centered: true,
            titleSize: 24,
            leading: IconTile(
              icon: Icons.link_off_rounded,
              size: 64,
              tone: IconTileTone.danger,
            ),
            title: 'Invalid Invitation',
            subtitle: 'That invite link or QR code is invalid or has expired.',
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.lg,
            fullWidth: true,
            onPressed: () => context.go(RoutePaths.home),
            child: const Text('Go home'),
          ),
        ],
      ),
    );
  }

  Widget _buildInvite() {
    final app = context.watch<AppProvider>();
    final alreadyIn =
        _preview != null && app.isMemberOfGroup(_preview!.gid);
    final joining = _state == _JoinState.joining;
    final hostName = _preview?.hostName;
    final memberNames = [
      if (hostName != null && hostName.isNotEmpty) hostName,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: AppTag('Group invite', tone: AppTagTone.primary)),
        const SizedBox(height: AppSpacing.xl),
        FormScreenHeader(
          centered: true,
          titleSize: 26,
          leading: IconTile(label: _groupInitials, size: 64),
          title: _groupName,
          subtitle: _invitedBy,
        ),
        const SizedBox(height: AppSpacing.xl),
        StatRowsCard(
          rows: [
            if (_memberCount > 0)
              StatRow(
                'Members',
                trailing: _AvatarStack(names: memberNames, total: _memberCount),
              ),
            if (_gamesCount != null)
              StatRow('Games played', value: '$_gamesCount'),
          ],
        ),
        if (_joinFailed) ...[
          const SizedBox(height: AppSpacing.md),
          Semantics(
            liveRegion: true,
            child: Text(
              'Could not join. Check your connection and try again.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.destructiveText,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
        AppButton(
          size: AppButtonSize.lg,
          fullWidth: true,
          onPressed: joining ? null : _join,
          child: Text(
            joining
                ? 'Joining…'
                : alreadyIn
                    ? 'Open group'
                    : 'Join group',
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        PromptLink(
          action: 'Not now',
          bold: false,
          onTap: _leave,
        ),
      ],
    );
  }
}

/// Up to three overlapping member initials plus a "+N" chip for the rest.
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.names, required this.total});

  final List<String> names;
  final int total;

  @override
  Widget build(BuildContext context) {
    final shown = names.take(3).toList();
    final extra = total - shown.length;
    Widget ring(Widget child) => Align(
      widthFactor: 0.72,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.card, width: 1.5),
        ),
        child: child,
      ),
    );
    return Semantics(
      label: '$total members',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final n in shown)
            ring(AppAvatar(name: n, size: AppAvatarSize.sm)),
          if (extra > 0)
            ring(
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '+$extra',
                  style: AppTypography.mono(size: 10, weight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
