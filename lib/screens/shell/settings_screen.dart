import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../../theme/theme_palette.dart';
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
          Text(
            'Settings',
            style: AppTypography.display(
              size: AppFontSizes.xxxl,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Preferences for your account',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Notifications
          Text(
            'Gameplay',
            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
          ),
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
                // Push notifications are unavailable on the free (Spark) plan:
                // there is no Cloud Function to fan out cross-user inbox items,
                // so the feature was dropped. Kept as a disabled informational
                // row rather than a broken toggle.
                _SettingRow(
                  icon: Icons.notifications_off_outlined,
                  title: 'Push notifications',
                  subtitle: 'Unavailable on the free plan',
                  trailing: Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: AppColors.mutedForeground,
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
          Text(
            'Game Assets',
            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingRow(
                  icon: Icons.casino_outlined,
                  title: 'Chip sets',
                  subtitle: 'Manage saved chip denominations and colours',
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.mutedForeground,
                  ),
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
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Standard set'),
                        ),
                        for (final set in app.savedChipSets)
                          DropdownMenuItem<String?>(
                            value: set.id,
                            child: Text(
                              set.name,
                              overflow: TextOverflow.ellipsis,
                            ),
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
          Text(
            'Appearance',
            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Dark / Light / System toggle
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                _ModeChip(
                  label: 'Dark',
                  active: app.themePreference == 'dark',
                  onTap: () => app.setThemePreference('dark'),
                ),
                const SizedBox(width: AppSpacing.sm),
                _ModeChip(
                  label: 'Light',
                  active: app.themePreference == 'light',
                  onTap: () => app.setThemePreference('light'),
                ),
                const SizedBox(width: AppSpacing.sm),
                _ModeChip(
                  label: 'System',
                  active: app.themePreference == 'system',
                  onTap: () => app.setThemePreference('system'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Color theme selector
          Text(
            'Color theme',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ThemeGrid(
            activeId: app.colorTheme,
            onSelect: (id) => app.setColorTheme(id),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Account
          Text(
            'Account',
            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 22,
                  color: AppColors.icon,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Guest',
                        style: AppTypography.bodySm.copyWith(
                          fontWeight: FontWeight.w600,
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
                if (user?.isAdmin == true)
                  const AppBadge(label: 'Admin', variant: AppBadgeVariant.gold),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            variant: AppButtonVariant.secondary,
            onPressed: () => _confirmSignOut(context, app),
            child: const Text('Sign out'),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppDivider(label: 'About'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Poker Night v1.0.0',
            textAlign: TextAlign.center,
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
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
          style: AppTypography.bodySm.copyWith(
            color: AppColors.mutedForeground,
          ),
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
              style: AppTypography.bodySm.copyWith(
                color: AppColors.destructive,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: active ? AppColors.primarySoft : AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
          ),
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

/// 3×2 grid of theme cards showing each palette's colours.
class _ThemeGrid extends StatelessWidget {
  const _ThemeGrid({required this.activeId, required this.onSelect});

  final String activeId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ThemePalettes.all.sublist(0, 3),
      ThemePalettes.all.sublist(3, 5),
    ];
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          for (final entry in rows.asMap().entries) ...[
            Row(
              children: [
                for (final p in entry.value) ...[
                  Expanded(
                    child: _ThemeCard(
                      palette: p,
                      selected: p.id == activeId,
                      onTap: () => onSelect(p.id),
                    ),
                  ),
                  if (p != entry.value.last)
                    const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
            if (entry.key < rows.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

/// A single theme card showing the palette name, a colour swatch preview,
/// and a small sample of the UI colours.
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final ThemePalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return InkWell
      (
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: selected ? palette.primary : palette.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colour swatch row: primary, background, card, border
            Row(
              children: [
                _swatch(palette.primary),
                const SizedBox(width: 4),
                _swatch(palette.background),
                const SizedBox(width: 4),
                _swatch(palette.card),
                const SizedBox(width: 4),
                _swatch(palette.border),
                if (selected) ...[
                  const Spacer(),
                  Icon(Icons.check_circle, size: 16, color: palette.primary),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              palette.name,
              style: AppTypography.bodyXs.copyWith(
                color: palette.foreground,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  static Widget _swatch(Color c) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: c.computeLuminance() > 0.5
              ? Colors.black.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.15),
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
    Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(bottom: BorderSide(color: AppColors.border))
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.icon),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
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
