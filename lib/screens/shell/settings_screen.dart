import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../../theme/theme_palette.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_toggle.dart';
import '../../widgets/back_nav_button.dart';

/// Settings screen matching F2_Settings mobile-first design.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _chooseDefaultChipSet(BuildContext context, AppProvider app) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF121417),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF22262B)),
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
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text(
                    'Standard set',
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: app.defaultChipSetId == null
                      ? const Icon(Icons.check, color: Color(0xFFD53032))
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
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: app.defaultChipSetId == set.id
                        ? const Icon(Icons.check, color: Color(0xFFD53032))
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
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Account and group preferences',
            style: AppTypography.bodySm.copyWith(
              color: const Color(0xFF8E8E93),
            ),
          ),
          const SizedBox(height: 24),

          // GAMEPLAY Section
          Text(
            'GAMEPLAY',
            style: AppTypography.bodyXs.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF71767B),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF121417),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF22262B)),
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
                  title: 'Admin app tour',
                  subtitle: 'Step-by-step guidance during tournaments',
                  trailing: AppToggle(
                    value: app.showAppTour,
                    onChanged: (v) => app.setAppTour(v),
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
              color: const Color(0xFF71767B),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF121417),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF22262B)),
            ),
            child: Column(
              children: [
                _buildSettingRow(
                  title: 'Chip sets',
                  subtitle: 'Manage saved denominations & colours',
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF71767B),
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
                        color: const Color(0xFF1E2227),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: const Color(0xFF2C3238)),
                      ),
                      child: Text(
                        defaultSetName,
                        style: AppTypography.bodyXs.copyWith(
                          color: const Color(0xFFD1D5DB),
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

          // APPEARANCE (Themes)
          Text(
            'APPEARANCE',
            style: AppTypography.bodyXs.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF71767B),
            ),
          ),
          const SizedBox(height: 10),
          _ThemeGrid(
            activeId: app.colorTheme,
            onSelect: (id) => app.setColorTheme(id),
          ),
          const SizedBox(height: 24),

          // ACCOUNT Section
          Text(
            'ACCOUNT',
            style: AppTypography.bodyXs.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF71767B),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF121417),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF22262B)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22262B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: Colors.white,
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
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? 'Not signed in',
                        style: AppTypography.bodyXs.copyWith(
                          color: const Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
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
                color: const Color(0xFF121417),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF22262B)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Sign out',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFEF4444),
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
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTypography.bodyXs.copyWith(
                    color: const Color(0xFF8E8E93),
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
          const Divider(height: 1, thickness: 1, color: Color(0xFF22262B)),
      ],
    );
  }

  void _confirmSignOut(BuildContext context, AppProvider app) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF121417),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF22262B)),
        ),
        title: const Text('Sign out?', style: TextStyle(color: Colors.white)),
        content: Text(
          'You will need to log in again to see your games.',
          style: AppTypography.bodySm.copyWith(color: const Color(0xFF8E8E93)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: AppTypography.bodySm.copyWith(
                color: const Color(0xFF8E8E93),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              app.logout();
              context.go(RoutePaths.landing);
            },
            child: const Text(
              'Sign out',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF121417),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF22262B)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = AppSpacing.sm;
          final available = constraints.maxWidth;
          var perRow = ((available + gap) / (_ThemeCard.minWidth + gap))
              .floor();
          perRow = perRow.clamp(1, 3);

          final rows = <List<ThemePalette>>[];
          for (var i = 0; i < ThemePalettes.all.length; i += perRow) {
            final end = (i + perRow < ThemePalettes.all.length)
                ? i + perRow
                : ThemePalettes.all.length;
            rows.add(ThemePalettes.all.sublist(i, end));
          }

          return Column(
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
                      if (p != entry.value.last) const SizedBox(width: gap),
                    ],
                    for (var i = entry.value.length; i < perRow; i++) ...[
                      const SizedBox(width: gap),
                      const Expanded(child: SizedBox.shrink()),
                    ],
                  ],
                ),
                if (entry.key < rows.length - 1)
                  const SizedBox(height: AppSpacing.sm),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final ThemePalette palette;
  final bool selected;
  final VoidCallback onTap;

  static const double minWidth = (16 * 4) + (4 * 3) + 16 + (AppSpacing.sm * 2);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? palette.primary : const Color(0xFF22262B),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    palette.name,
                    style: AppTypography.bodyXs.copyWith(
                      color: palette.foreground,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (selected)
                  Icon(Icons.check, size: 14, color: palette.primary),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                _Swatch(palette.primary),
                const SizedBox(width: AppSpacing.xxs),
                _Swatch(palette.card),
                const SizedBox(width: AppSpacing.xxs),
                _Swatch(palette.border),
                const SizedBox(width: AppSpacing.xxs),
                _Swatch(palette.mutedForeground),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
    );
  }
}
