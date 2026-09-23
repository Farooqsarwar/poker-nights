import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../../services/push_service.dart';
import '../../services/onesignal_sender.dart';
import '../../theme/theme_palette.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_divider.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_select.dart';
import '../../widgets/app_toggle.dart';
import '../../widgets/group_switcher.dart';
import '../../app/icons.dart';

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
          const GroupContextHeader(title: 'Settings'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Account and group preferences',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // ── Group settings ───────────────────────────────────────────────
          // Group settings live in one place so the user never wonders
          // whether a setting changes them or the group (IA §4).
          if (app.hasCurrentGroup) ...[
            Text(
              'Your group',
              style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            _GroupSettingsCard(app: app),
            const SizedBox(height: AppSpacing.xl),
          ],
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
                _SettingRow(
                  icon: Icons.lightbulb_outline,
                  title: 'Admin app tour',
                  subtitle: 'Show step-by-step guidance during tournaments',
                  trailing: AppToggle(
                    value: app.showAppTour,
                    onChanged: (v) => app.setAppTour(v),
                  ),
                  showDivider: true,
                ),
                // Push notifications via OneSignal (free-plan fan-out — no
                // Cloud Function). Toggling on shows the OS/browser prompt.
                _SettingRow(
                  icon: Icons.notifications_outlined,
                  title: 'Push notifications',
                  subtitle:
                      'Tournament, RSVP and result alerts on every device',
                  trailing: AppToggle(
                    value: app.notificationsEnabled,
                    onChanged: (v) async {
                      final error = await app.setNotificationsEnabled(v);
                      if (error != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error)),
                        );
                      }
                    },
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
          // Developer / Debug
          Text(
            'Developer',
            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: InkWell(
              onTap: () {
                final push = PushService.instance;
                if (!push.permissionGranted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Push permission not granted!')),
                  );
                  return;
                }
                if (!OneSignalSender.instance.configured) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Push not configured — missing ONESIGNAL_REST_API_KEY.',
                      ),
                    ),
                  );
                  return;
                }
                if (app.user == null) return;
                OneSignalSender.instance.send(
                  title: 'Debug Push',
                  body: 'Hello! Your push notifications are working perfectly.',
                  externalIds: [app.user!.id],
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Test push sent! It should arrive shortly.')),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Icon(Icons.bug_report, size: 20, color: AppColors.icon),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Send Test Push (Debug)', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: AppSpacing.xxs),
                          Text('Fires a real push to this device.', style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        user?.email ?? 'Not signed in',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                if (app.isAdmin)
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
                color: AppColors.destructiveText,
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
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      // The number of cards per row used to be hardcoded at 3. A card's
      // contents have a hard floor — four 16px swatches, three 4px gaps and,
      // when selected, a 16px check — so it cannot render below
      // [_ThemeCard.minWidth]. On a 400px phone a third of the row came out
      // under that and the swatch strip overflowed; on a 320px phone it
      // overflowed on several rows at once. Deriving the count from the width
      // we are actually given fixes it at every size instead of at the two we
      // happened to test.
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
                      if (p != entry.value.last)
                        const SizedBox(width: gap),
                    ],
                    // A short last row (5 palettes over rows of 3 leaves 2)
                    // keeps its cards the same size as the full rows above
                    // rather than stretching them across the gap.
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

  /// The narrowest this card can be drawn without its swatch strip
  /// overflowing: four 16px swatches, three 4px gaps and a 16px check mark
  /// when selected, plus [AppSpacing.sm] of padding on each side.
  /// [_ThemeSection] uses it to decide how many cards fit on a row.
  static const double minWidth = (16 * 4) + (4 * 3) + 16 + (AppSpacing.sm * 2);

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
                const SizedBox(width: AppSpacing.xs),
                _swatch(palette.background),
                const SizedBox(width: AppSpacing.xs),
                _swatch(palette.card),
                const SizedBox(width: AppSpacing.xs),
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
                  const SizedBox(height: AppSpacing.xxs),
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

/// Group settings section — group name, members, game defaults, invite code,
/// and the danger zone (leave / transfer). Keeps group concerns clearly
/// separate from account/app preferences (IA §4).
class _GroupSettingsCard extends StatelessWidget {
  const _GroupSettingsCard({required this.app});

  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    final group = app.currentGroup;
    final chip = Icons.chevron_right;
    final chevron = Icon(chip, color: AppColors.mutedForeground, size: 20);

    void copyCode() {
      Clipboard.setData(ClipboardData(text: group.joinCode));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group code copied to clipboard')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _SettingRow(
                icon: groupIconMap[group.icon] ?? Icons.shield_outlined,
                title: group.name,
                subtitle: '${group.members.length} members ○ ${group.ownerId == app.user?.id ? 'You own this group' : 'Group details'}',
                trailing: chevron,
                showDivider: true,
                onTap: () => context.go(RoutePaths.group),
              ),
              _SettingRow(
                icon: Icons.groups_outlined,
                title: 'Manage members',
                subtitle: 'Admins, co-admins, remove members',
                trailing: chevron,
                showDivider: true,
                onTap: () =>
                    context.go(RoutePaths.members),
              ),
              _SettingRow(
                icon: Icons.style_outlined,
                title: 'Game defaults',
                subtitle: 'Chip sets and tournament presets',
                trailing: chevron,
                showDivider: true,
                onTap: () => context.push(RoutePaths.presets),
              ),
              _SettingRow(
                icon: Icons.qr_code_2_outlined,
                title: 'Invite members',
                subtitle: 'Group code: ${group.joinCode} · tap to copy',
                trailing: chevron,
                showDivider: false,
                onTap: copyCode,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: EdgeInsets.zero,
          borderColor: AppColors.destructive.withValues(alpha: 0.3),
          child: Column(
            children: [
              if (app.isAdmin)
                _SettingRow(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Transfer ownership',
                  subtitle: 'Hand the group to another member',
                  trailing: chevron,
                  showDivider: true,
                  onTap: () => _showTransferOwnershipDialog(context),
                ),
              InkWell(
                onTap: () => _confirmLeaveGroup(context),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Icon(
                        Icons.exit_to_app_outlined,
                        size: 20,
                        color: AppColors.destructiveText,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Leave group',
                              style: AppTypography.bodySm.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.destructive,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              'You can rejoin with the group code',
                              style: AppTypography.bodyXs.copyWith(
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: AppColors.destructive.withValues(alpha: 0.6),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmLeaveGroup(BuildContext context) {
    final app = this.app;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Leave Group'),
        content: const Text(
          'Leave this group? You can rejoin with the group code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              app.leaveGroup();
              context.go(RoutePaths.home);
            },
            child: Text(
              'Leave',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.destructiveText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTransferOwnershipDialog(BuildContext context) {
    final app = this.app;
    final members = app.currentGroup.members
        .where((m) => m.id != app.user?.id)
        .toList();
    if (members.isEmpty) return;
    String? selectedId;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Transfer Ownership'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select a member to become the new group owner. This cannot be undone.',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Selection moved to the RadioGroup ancestor — same migration as
              // the identical dialog in `group_screen.dart`.
              RadioGroup<String>(
                groupValue: selectedId,
                onChanged: (v) => setState(() => selectedId = v),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...members.map(
                      (m) => RadioListTile<String>(
                        value: m.id,
                        title: Text(m.name, style: AppTypography.bodySm),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
            TextButton(
              onPressed: selectedId == null
                  ? null
                  : () async {
                      Navigator.of(ctx).pop();
                      await app.transferGroupOwnership(selectedId!);
                    },
              child: const Text('Transfer'),
            ),
          ],
        ),
      ),
    );
  }
}
