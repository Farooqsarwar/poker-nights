import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_page.dart';

/// Landing page for a group invite link/QR code (`/join-group?code=...`).
/// Requires sign-in (the router bounces unauthenticated visitors through
/// login with `?next=` and returns them here) — group membership has no
/// guest-session equivalent, unlike the per-tournament guest flow.
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
        if (mounted) context.go('${RoutePaths.group}?tab=members');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      maxWidth: 480,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.huge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              switch (_state) {
                _JoinState.working => const CircularProgressIndicator(),
                _JoinState.success => Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 48,
                  ),
                _JoinState.failure => Icon(
                    Icons.error_outline,
                    color: AppColors.destructive,
                    size: 48,
                  ),
              },
              const SizedBox(height: AppSpacing.lg),
              Text(
                switch (_state) {
                  _JoinState.working => 'Joining group…',
                  _JoinState.success => 'You\'re in! Taking you there…',
                  _JoinState.failure =>
                    'That invite link/QR code is invalid or expired.',
                },
                textAlign: TextAlign.center,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              if (_state == _JoinState.failure) ...[
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  onPressed: () => context.go(RoutePaths.home),
                  child: const Text('Go home'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
