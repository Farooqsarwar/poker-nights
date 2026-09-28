import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/colors.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_toggle.dart';
import '../../widgets/back_nav_button.dart';
import '../../widgets/delete_account_flow.dart';

/// Settings screen matching F2_Settings mobile-first design.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _chooseDefaultChipSet(BuildContext context, AppProvider app) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Default Chip Set',
                  style: AppTypography.bodyLg.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(
                    'Standard set',
                    style: TextStyle(color: AppColors.foreground),
                  ),
                  trailing: app.defaultChipSetId == null
                      ? Icon(Icons.check, color: AppColors.primary)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () {
                    app.setDefaultChipSet(null);
                    Navigator.of(bottomSheetContext).pop();
                  },
                ),
                for (final set in app.savedChipSets)
                  ListTile(
                    title: Text(
                      set.name,
                      style: TextStyle(color: AppColors.foreground),
                    ),
                    trailing: app.defaultChipSetId == set.id
                        ? Icon(Icons.check, color: AppColors.primary)
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () {
                      app.setDefaultChipSet(set.id);
                      Navigator.of(bottomSheetContext).pop();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final user = app.user;

    final defaultSetName = app.defaultChipSetId == null
        ? 'STANDARD SET'
        : (app.savedChipSets
                  .where((c) => c.id == app.defaultChipSetId)
                  .firstOrNull
                  ?.name
                  .toUpperCase() ??
              'STANDARD SET');

    return AppPage(
      maxWidth: 520,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // App bar with Squircle back button <
          Row(
            children: [
              BackNavButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(RoutePaths.profile);
                  }
                },
                label: 'Back',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Title & Subtitle
          Text(
            'Settings',
            style: AppTypography.display(
              size: 30,
              weight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Account and group preferences',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 24),

          // GAMEPLAY Section
          Text(
            'GAMEPLAY',
            style: AppTypography.bodyXs.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceHint,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              children: [
                _buildSettingRow(
                  title: 'Voice announcements',
                  subtitle: 'Spoken blinds and level updates',
                  trailing: AppToggle(
                    value: app.voiceEnabled,
                    onChanged: (v) => app.setVoiceEnabled(v),
                  ),
                  showDivider: true,
                ),
                _buildSettingRow(
                  title: 'Push notifications',
                  subtitle: 'Tournament, RSVP and result alerts',
                  trailing: AppToggle(
                    value: app.notificationsEnabled,
                    onChanged: (v) async {
                      final error = await app.setNotificationsEnabled(v);
                      if (error != null && context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(error)));
                      }
                    },
                  ),
                  showDivider: true,
                ),
                _buildSettingRow(
                  title: 'Compact results',
                  subtitle: 'Fewer details in game summaries',
                  trailing: AppToggle(
                    value: app.compactSummary,
                    onChanged: (v) => app.setCompactSummary(v),
                  ),
                  showDivider: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // GAME ASSETS Section
          Text(
            'GAME ASSETS',
            style: AppTypography.bodyXs.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceHint,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              children: [
                _buildSettingRow(
                  title: 'Chip sets',
                  subtitle: 'Manage saved denominations & colours',
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.onSurfaceHint,
                    size: 20,
                  ),
                  onTap: () => context.push(RoutePaths.chipSets),
                  showDivider: true,
                ),
                _buildSettingRow(
                  title: 'Default chip set',
                  subtitle: 'Used when you create a new tournament',
                  trailing: GestureDetector(
                    onTap: () => _chooseDefaultChipSet(context, app),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.muted,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Text(
                        defaultSetName,
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.secondaryForeground,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                  showDivider: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // §B1 opens "Exactly one look: black ground, crimson accent, white
          // ink." There is nothing to choose between, so the APPEARANCE
          // section and its theme grid are gone rather than reduced to a
          // single-option picker.

          // ACCOUNT Section
          Text(
            'ACCOUNT',
            style: AppTypography.bodyXs.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceHint,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.borderSubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person_outline,
                    color: AppColors.foreground,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Guest',
                        style: AppTypography.bodySm.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? 'Not signed in',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // DATA Section (§F2 DATA)
          Text(
            'DATA',
            style: AppTypography.bodyXs.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceHint,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              children: [
                _buildSettingRow(
                  title: 'Keep my game history to improve structures',
                  subtitle:
                      'Lets pace and finish-time forecasts learn from your real '
                      'nights. Each group can opt out separately.',
                  trailing: AppToggle(
                    value: app.keepHistoryForStructures,
                    onChanged: (v) => app.setKeepHistoryForStructures(v),
                  ),
                  showDivider: true,
                ),
                _buildSettingRow(
                  title: 'Export my data',
                  subtitle: 'Copy everything this account owns as JSON',
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.onSurfaceHint,
                    size: 20,
                  ),
                  onTap: () => _exportMyData(context, app),
                  showDivider: true,
                ),
                _buildSettingRow(
                  title: 'Delete account',
                  subtitle: 'Permanently remove your account and all data',
                  trailing: Icon(
                    Icons.delete_outline,
                    color: AppColors.destructiveText,
                    size: 20,
                  ),
                  onTap: () => confirmDeleteAccount(context, app),
                  showDivider: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Sign out card button (F2 design)
          InkWell(
            onTap: () => _confirmSignOut(context, app),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sign out',
                    style: TextStyle(
                      color: AppColors.destructiveText,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    Icons.logout_rounded,
                    color: AppColors.destructiveText,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// §F2 DATA — "Export my data".
  ///
  /// Copies the export to the clipboard rather than writing a file: the app
  /// ships no file-download or share dependency, and a `data:` URL behaves
  /// differently on web, iOS and Android. The clipboard works identically
  /// everywhere, so the user gets their data in one tap on every platform.
  /// The JSON is shown as well, so nobody has to paste it somewhere to find
  /// out what they just copied.
  void _exportMyData(BuildContext context, AppProvider app) {
    final json = app.exportMyData();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Your data'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: SelectableText(
              json,
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.mutedForeground,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Close',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(dialogContext);
              await Clipboard.setData(ClipboardData(text: json));
              messenger.showSnackBar(
                const SnackBar(content: Text('Your data was copied.')),
              );
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: Text(
              'Copy',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.primaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildSettingRow({
    required String title,
    required String subtitle,
    required Widget trailing,
    required bool showDivider,
    VoidCallback? onTap,
  }) {
    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );

    if (onTap != null) {
      content = InkWell(onTap: onTap, child: content);
    }

    return Column(
      children: [
        content,
        if (showDivider)
          Divider(height: 1, thickness: 1, color: AppColors.borderSubtle),
      ],
    );
  }

  void _confirmSignOut(BuildContext context, AppProvider app) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.borderSubtle),
        ),
        title: Text('Sign out?', style: TextStyle(color: AppColors.foreground)),
        content: Text(
          'You will need to log in again to see your games.',
          style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              app.logout();
              context.go(RoutePaths.landing);
            },
            child: Text(
              'Sign out',
              style: TextStyle(
                color: AppColors.destructiveText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

