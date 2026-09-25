import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
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

  String get _groupName => context.read<AppProvider>().currentGroup.name;

  int get _memberCount => context.read<AppProvider>().currentGroup.members.length;

  String get _groupInitials {
    final name = _groupName;
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.map((p) => p[0].toUpperCase()).join().substring(0, parts.length >= 2 ? 2 : 1);
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
    if (ok) {
      Future.delayed(AppDurations.slow, () {
        if (mounted) context.go(RoutePaths.members);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Single cohesive card for every state — the group's identity is the
    // payload once it resolves, so it reads as one surface growing to fit
    // rather than a status line with a separate card bolted underneath.
    // Purely presentational: the auto-join call and its timing (initState /
    // _attemptJoin / the delayed forward nav) are unchanged below.
    return AppPage(
      maxWidth: 480,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.huge),
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
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
                  style: _state == _JoinState.working
                      ? AppTypography.bodySm.copyWith(
                          color: AppColors.mutedForeground,
                        )
                      : AppTypography.display(size: AppFontSizes.lg),
                ),
                if (_state == _JoinState.success) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Container(height: 1, color: AppColors.border),
                  const SizedBox(height: AppSpacing.xl),
                  // The group's mark and name, and its member count — the
                  // invite's identity, confirmed. The auto-join and forward
                  // navigation above are unchanged.
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      _groupInitials,
                      style: AppTypography.display(
                        size: AppFontSizes.lg,
                        weight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _groupName,
                    textAlign: TextAlign.center,
                    style: AppTypography.display(
                      size: AppFontSizes.xl,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '$_memberCount members',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
                if (_state == _JoinState.failure) ...[
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    fullWidth: true,
                    onPressed: () => context.go(RoutePaths.home),
                    child: const Text('Go home'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
