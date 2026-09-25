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

/// Landing page for a group invite link/QR code (`/join-group?code=...`).
/// Matches the A8 Join Group frame: group-invite tag, initials tile, group
/// name, inviter, a members / games-played summary, and the actions.
///
/// The join runs on open; once it succeeds the screen shows the group it
/// joined, with "Join group" opening it and "Not now" going home.
class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key, required this.code});

  final String code;

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

enum _JoinState { working, success, failure }

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  _JoinState _state = _JoinState.working;

  String get _groupName => context.read<AppProvider>().currentGroup.name;

  int get _memberCount =>
      context.read<AppProvider>().currentGroup.members.length;

  int get _gamesCount => context.read<AppProvider>().currentGroup.games.length;

  String get _invitedBy {
    final group = context.read<AppProvider>().currentGroup;
    final owner = group.members.where((m) => m.id == group.ownerId).firstOrNull;
    if (owner != null && owner.name.isNotEmpty) {
      return 'Invited by ${owner.name}';
    }
    return 'You\'ve been invited to join';
  }

  String get _groupInitials {
    final name = _groupName;
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return 'FP';
    return parts
        .map((p) => p[0].toUpperCase())
        .join()
        .substring(0, parts.length >= 2 ? 2 : 1);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attemptJoin());
  }

  Future<void> _attemptJoin() async {
    final ok = await context.read<AppProvider>().joinGroup(widget.code);
    if (!mounted) return;
    setState(() => _state = ok ? _JoinState.success : _JoinState.failure);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final group = app.currentGroup;

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
                onTap: () => context.go(RoutePaths.home),
                tooltip: 'Back',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          switch (_state) {
            _JoinState.working => _buildWorking(),
            _JoinState.failure => _buildFailure(),
            _JoinState.success => _buildInvite(
              [for (final m in group.members) m.name],
            ),
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

  Widget _buildInvite(List<String> memberNames) {
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
            StatRow(
              'Members',
              trailing: _AvatarStack(names: memberNames, total: _memberCount),
            ),
            StatRow('Games played', value: '$_gamesCount'),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        AppButton(
          size: AppButtonSize.lg,
          fullWidth: true,
          onPressed: () => context.go(RoutePaths.group),
          child: const Text('Join group'),
        ),
        const SizedBox(height: AppSpacing.xs),
        PromptLink(
          action: 'Not now',
          bold: false,
          onTap: () => context.go(RoutePaths.home),
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
