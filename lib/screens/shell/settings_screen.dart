import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/colors.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../../services/payment_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_toggle.dart';
import '../../widgets/back_nav_button.dart';
import '../../widgets/delete_account_flow.dart';

class _CurrencyChoice extends StatelessWidget {
  const _CurrencyChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label == 'None' ? 'No currency symbol' : 'Currency $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          constraints: const BoxConstraints(minWidth: 56, minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : AppColors.muted,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.borderSubtle,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.bodySm.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.primaryText : AppColors.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

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
    final blockedCount = app.blockedUserIds.length;

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

          // ON THIS PHONE Section (F2): choices that change how this phone
          // shows things and are never shared with the group.
          Text(
            'ON THIS PHONE',
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Currency',
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'A symbol in front of money on this phone. Chip counts '
                    'never get one.',
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in const [
                        ('None', ''),
                        ('€', '€'),
                        ('\$', '\$'),
                        ('£', '£'),
                      ])
                        _CurrencyChoice(
                          label: option.$1,
                          selected: app.currencySymbol == option.$2,
                          onTap: () => app.setCurrencySymbol(option.$2),
                        ),
                    ],
                  ),
                ],
              ),
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
          const SizedBox(height: 10),

          // §E10 (3) "until unblocked in Settings -> Blocked" / §B4 "undo in
          // Settings -> Blocked". The row is ALWAYS visible, unlike the
          // conditional Reports row in §B9: a block is undone here and
          // nowhere else, and the message it hid is exactly the thing the
          // user can no longer see. A row that vanished with the last
          // unblock would make the undo path undiscoverable, and the empty
          // state below is written for exactly that case.
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: _buildSettingRow(
              title: 'Blocked',
              // The subtitle describes the destination rather than repeating
              // the sheet's empty state, so each string has one owner and the
              // row still reads correctly with nothing blocked.
              subtitle: blockedCount == 0
                  ? 'Manage who you have blocked'
                  : 'Their messages and polls are hidden for you',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (blockedCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '$blockedCount',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.primaryText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.onSurfaceHint,
                    size: 20,
                  ),
                ],
              ),
              onTap: () => _showBlockedMembers(context, app),
              showDivider: false,
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

          // PLAN Section (F2): what this account has, and the way to Premium.
          Text(
            'PLAN',
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
                  title: app.premiumTier == PremiumTier.premium
                      ? 'Premium'
                      : 'Free',
                  subtitle: app.premiumTier == PremiumTier.premium
                      ? 'More tables, seasons, bounties and custom TV layouts'
                      : 'Upgrade for more tables, seasons and bounties',
                  trailing: Text(
                    app.premiumTier == PremiumTier.premium
                        ? 'Manage'
                        : 'See Premium',
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () => context.push(RoutePaths.upgrade),
                  showDivider: true,
                ),
                _buildSettingRow(
                  title: 'Terms of Service',
                  subtitle: 'The rules for using Poker Night',
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.onSurfaceHint,
                    size: 20,
                  ),
                  onTap: () => context.push(RoutePaths.terms),
                  showDivider: true,
                ),
                _buildSettingRow(
                  title: 'Privacy Policy',
                  subtitle: 'What we keep and why',
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.onSurfaceHint,
                    size: 20,
                  ),
                  onTap: () => context.push(RoutePaths.privacy),
                  showDivider: true,
                ),
                _buildSettingRow(
                  title: 'Help & support',
                  subtitle: 'Answers and how to reach us',
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.onSurfaceHint,
                    size: 20,
                  ),
                  onTap: () => context.push(RoutePaths.support),
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

  /// §E10 (3) / §B4 — the account-wide undo for a block.
  ///
  /// Reads the blocked ids from the provider on every rebuild instead of
  /// snapshotting them once, so an unblock updates the list in place and the
  /// empty state takes over when the last one goes. A `StatefulBuilder` is
  /// what makes that work: this is a dialog, so it does not sit under the
  /// `context.watch` in [build] and would not otherwise see `notifyListeners`.
  ///
  /// Names come from the current group's roster so a row reads as a person; a
  /// member who has since left the group falls back to their raw id rather
  /// than showing a blank.
  void _showBlockedMembers(BuildContext context, AppProvider app) {
    final group = app.currentGroup;
    String nameOf(String id) {
      final match = group.members.where((m) => m.id == id).firstOrNull;
      final name = match?.name.trim() ?? '';
      return name.isEmpty ? id : name;
    }

    showAppModal(
      context: context,
      title: 'Blocked members',
      child: StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final ids = app.blockedUserIds.toList();
          if (ids.isEmpty) {
            return Text(
              'Nobody is blocked.',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Their messages and polls are hidden for you. Unblocking '
                'brings the whole conversation back.',
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final id in ids)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.muted,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            child: Row(
                              children: [
                                AppAvatar(
                                  name: nameOf(id),
                                  size: AppAvatarSize.sm,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    nameOf(id),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodySm.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    if (app.unblockUser(id)) {
                                      setSheetState(() {});
                                      ScaffoldMessenger.maybeOf(context)
                                        ?.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '${nameOf(id)} is unblocked.',
                                            ),
                                          ),
                                        );
                                    }
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primaryText,
                                    visualDensity: VisualDensity.compact,
                                    minimumSize: const Size(44, 44),
                                  ),
                                  child: const Text('Unblock'),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
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

