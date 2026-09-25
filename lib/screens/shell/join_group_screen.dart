import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/form_screen_header.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/stat_rows_card.dart';

/// Landing page for a group invite link/QR code (`/join-group?code=...`).
/// Requires sign-in (the router bounces unauthenticated visitors through
/// login with `?next=` and returns them here) — group membership has no
/// guest-session equivalent, unlike the per-tournament guest flow.
///
/// Laid out in the redesign's A8 language (eyebrow, crimson tile, title, a
/// detail card). The join itself still runs automatically on open — there is
/// no preview lookup for a group you are not yet in, so the A8 frame's group
/// name, inviter, member stack and games-played count are not shown.
class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key, required this.code});

  final String code;

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

enum _JoinState { working, success, failure }

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  _JoinState _state = _JoinState.working;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attemptJoin());
  }

  Future<void> _attemptJoin() async {
    final ok = await context.read<AppProvider>().joinGroup(widget.code);
    if (!mounted) return;
    setState(() => _state = ok ? _JoinState.success : _JoinState.failure);
    if (ok) {
      Future.delayed(AppDurations.slow, () {
        if (mounted) context.go(RoutePaths.members);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.code.trim().toUpperCase();

    final tile = switch (_state) {
      _JoinState.working => IconTile(
        size: 64,
        semanticLabel: 'Joining',
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.primaryForeground,
          ),
        ),
      ),
      _JoinState.success => const IconTile(
        icon: Icons.check_rounded,
        size: 64,
        tone: IconTileTone.success,
        semanticLabel: 'Joined',
      ),
      _JoinState.failure => const IconTile(
        icon: Icons.link_off_rounded,
        size: 64,
        tone: IconTileTone.danger,
        semanticLabel: 'Invite not valid',
      ),
    };

    return AppPage(
      maxWidth: 480,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: AppTag(
                'Group invite',
                tone: _state == _JoinState.failure
                    ? AppTagTone.danger
                    : AppTagTone.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              liveRegion: true,
              child: FormScreenHeader(
                centered: true,
                titleSize: 26,
                leading: tile,
                title: switch (_state) {
                  _JoinState.working => 'Joining group…',
                  _JoinState.success => 'You\'re in!',
                  _JoinState.failure => 'Invite not valid',
                },
                subtitle: switch (_state) {
                  _JoinState.working => 'Hang on while we add you.',
                  _JoinState.success => 'Taking you there…',
                  _JoinState.failure =>
                    'That invite link/QR code is invalid or expired.',
                },
              ),
            ),
            if (code.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              StatRowsCard(rows: [StatRow('Invite code', value: code)]),
            ],
            if (_state == _JoinState.failure) ...[
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                fullWidth: true,
                size: AppButtonSize.lg,
                onPressed: () => context.go(RoutePaths.home),
                child: const Text('Go home'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
