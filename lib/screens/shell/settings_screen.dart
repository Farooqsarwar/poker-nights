import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_divider.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_select.dart';
import '../../widgets/app_toggle.dart';

/// Settings mirroring the account area of the web app.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final user = app.user;

    return AppPage(
      maxWidth: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Settings', style: AppTypography.display(size: AppFontSizes.xxxl, weight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Preferences for your account',
            style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Notifications
          Text('Gameplay', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingRow(
                  icon: Icons.volume_up_outlined,
                  title: 'Voice announcements',
                  subtitle: 'Spoken blinds and level updates',
                  trailing: AppToggle(
                    value: app.voiceEnabled,
                    onChanged: (v) => app.setVoiceEnabled(v),
                  ),
                  showDivider: true,
                ),
                // Audit fix C6: SMS alerts ("Email and SMS are not required",
                // Tech §14.3) and chip-sound effects (not in the voice spec,
                // §13.2) were out of MVP scope and were removed.
                _SettingRow(
                  icon: Icons.notifications_outlined,
                  title: 'Push notifications',
                  subtitle: 'Get alerts for RSVPs and game events',
                  trailing: AppToggle(
                    value: app.notificationsEnabled,
                    onChanged: (v) => app.setNotificationsEnabled(v),
                  ),
                  showDivider: false,
                ),
                _SettingRow(
                  icon: Icons.description_outlined,
                  title: 'Compact results',
                  subtitle: 'Show fewer details in game summaries',
                  trailing: AppToggle(
                    value: app.compactSummary,
                    onChanged: (v) => app.setCompactSummary(v),
                  ),
                  showDivider: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Game Assets
          Text('Game Assets', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingRow(
                  icon: Icons.casino_outlined,
                  title: 'Chip sets',
                  subtitle: 'Manage saved chip denominations and colours',
                  trailing: const Icon(Icons.chevron_right, color: AppColors.mutedForeground),
                  showDivider: false,
                  onTap: () => context.push(RoutePaths.chipSets),
                ),
                _SettingRow(
                  icon: Icons.casino_outlined,
                  title: 'Default chip set',
                  subtitle: 'Used when you create a new tournament',
                  trailing: SizedBox(
                    width: 160,
                    child: AppSelect<String?>(
                      value: app.defaultChipSetId,
                      onChanged: app.setDefaultChipSet,
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Standard set')),
                        for (final set in app.savedChipSets)
                          DropdownMenuItem<String?>(
                            value: set.id,
                            child: Text(set.name, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                    ),
                  ),
                  showDivider: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Appearance
          Text('Appearance', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                _ThemeChip(
                  label: 'Dark',
                  active: app.themePreference == 'dark',
                  onTap: () => app.setThemePreference('dark'),
                ),
                const SizedBox(width: AppSpacing.sm),
                _ThemeChip(
                  label: 'Light',
                  active: app.themePreference == 'light',
                  onTap: () => app.setThemePreference('light'),
                ),
                const SizedBox(width: AppSpacing.sm),
                _ThemeChip(
                  label: 'System',
                  active: app.themePreference == 'system',
                  onTap: () => app.setThemePreference('system'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Account
          Text('Account', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                const Icon(Icons.person_outline, size: 22, color: AppColors.icon),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Guest',
                        style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? 'Not signed in',
                        style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                      ),
                    ],
                  ),
                ),
                if (user?.isAdmin == true) const AppBadge(label: 'Admin', variant: AppBadgeVariant.gold),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            variant: AppButtonVariant.danger,
            onPressed: () => _confirmSignOut(context, app),
            child: const Text('Sign out'),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppDivider(label: 'About'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Poker Night v1.0.0',
            textAlign: TextAlign.center,
            style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, AppProvider app) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Sign out?'),
        content: Text(
          'You will need to log in again to see your games.',
          style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancel', style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              app.logout();
              context.go(RoutePaths.landing);
            },
            child: Text('Sign out', style: AppTypography.bodySm.copyWith(color: AppColors.destructive)),
          ),
        ],
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: active ? AppColors.primarySoft : AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: active ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: AppTypography.bodySm.copyWith(
            color: active ? AppColors.primary : AppColors.mutedForeground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.showDivider,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final bool showDivider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          border: showDivider ? const Border(bottom: BorderSide(color: AppColors.border)) : null,
        ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.icon),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          trailing,
        ],
      ),
      ),
    );
  }
}
