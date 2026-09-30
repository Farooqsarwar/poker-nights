import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/app_notification.dart';
import '../../models/chat_report.dart';
import '../../models/table_settings.dart';
import '../../providers/app_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_alert_banner.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_toggle.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/count_stepper.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/page_header.dart';

/// §B9 — the group's own settings. Host only (the router holds this path in
/// the admin set), and a member who reaches it anyway gets the same lock
/// [ImportResultsScreen] shows rather than a half-rendered form.
///
/// Two things on this screen are deliberately NOT wired: deleting the group
/// and re-rolling its join code. There is no provider method behind either, and
/// guessing a Firestore write for an irreversible action is how a group ends
/// up half-deleted. They ship inert with a note until the backend calls exist.
class GroupSettingsScreen extends StatefulWidget {
  const GroupSettingsScreen({super.key});

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  /// The table settings the host is editing but has not saved yet, and the
  /// stored value it was seeded from.
  ///
  /// Keyed off the stored value rather than reset in `didChangeDependencies`:
  /// a save from another device must pull the draft back to what is actually
  /// stored, or the next Save would silently overwrite the newer value with
  /// the one this device was holding.
  TableSettings? _draft;
  TableSettings? _draftFrom;

  /// The §B9 principle, shown behind "Why?".
  bool _showPrinciple = false;

  /// The value on screen: the draft while one is pending, the stored value
  /// otherwise.
  TableSettings _editing(TableSettings stored) {
    final draft = _draft;
    if (draft == null || _draftFrom != stored) return stored;
    return draft;
  }

  void _edit(TableSettings stored, TableSettings next) {
    setState(() {
      _draft = next;
      _draftFrom = stored;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    if (!app.isAdmin) {
      return _NotHost(
        onBack: () => context.go(RoutePaths.group),
        message: 'Only the host of this group can change its settings.',
      );
    }

    final group = app.currentGroup;
    // `updateGroupTableSettings` and `removeMember` both refuse anyone who is
    // not the owner, so a co-host sees these rows read-only rather than
    // watching a control silently do nothing.
    final isOwner = group.ownerId.isNotEmpty && group.ownerId == app.user?.id;
    final stored = group.tableSettings;
    final draft = _editing(stored);
    final dirty = draft != stored;

    return AppPage(
      maxWidth: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            onBack: () => context.go(RoutePaths.group),
            title: 'Group settings',
            subtitle: 'What every game in ${group.name} starts from',
            titleAction: AppButton(
              size: AppButtonSize.sm,
              variant: AppButtonVariant.ghost,
              onPressed: () => setState(() => _showPrinciple = !_showPrinciple),
              child: Text(_showPrinciple ? 'Hide' : 'Why?'),
            ),
          ),
          if (_showPrinciple) ...[
            const SizedBox(height: AppSpacing.lg),
            const _Principle(),
          ],
          const SizedBox(height: AppSpacing.lg),

          AppCard(
            child: Column(
              children: [
                _Row(
                  icon: Icons.style_outlined,
                  title: 'Default chip set',
                  subtitle: _chipSetSubtitle(app),
                  onTap: () => context.push(RoutePaths.groupChips),
                ),
                const _Divider(),
                _Row(
                  icon: Icons.emoji_events_outlined,
                  title: 'Standings and seasons',
                  subtitle: 'How the group has done over the season',
                  onTap: () => context.push(RoutePaths.standings),
                ),
                const _Divider(),
                _Row(
                  icon: Icons.history,
                  title: 'History',
                  subtitle: 'Every night this group has played',
                  onTap: () => context.push(RoutePaths.history),
                ),
                const _Divider(),
                _Row(
                  icon: Icons.group_outlined,
                  title: 'Members and roles',
                  subtitle:
                      '${group.members.length} ${group.members.length == 1 ? 'member' : 'members'} · hosts, co-hosts and members',
                  onTap: () => context.push(RoutePaths.members),
                ),
                const _Divider(),
                _Row(
                  icon: Icons.content_paste_go_outlined,
                  title: 'Import past results',
                  subtitle: "Bring last season's nights in",
                  onTap: () => context.push(RoutePaths.importResults),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          _TableSettingsCard(
            draft: draft,
            dirty: dirty,
            canEdit: isOwner,
            onChanged: (next) => _edit(stored, next),
            onSave: () {
              app.updateGroupTableSettings(draft);
              setState(() {
                _draft = null;
                _draftFrom = null;
              });
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          // §B9: "the row appears when there is one". A Reports card sitting
          // there permanently on every host's settings screen would be a
          // standing alarm for a group with nothing reported.
          if (app.reportCount > 0) ...[
            _ReportsCard(reports: app.reports, isOwner: isOwner),
            const SizedBox(height: AppSpacing.lg),
          ],

          _GroupCodeCard(joinCode: group.joinCode, canReroll: isOwner),
          const SizedBox(height: AppSpacing.lg),

          isOwner ? const _DeleteGroupCard() : _LeaveGroupCard(),
        ],
      ),
    );
  }

  /// §B9: a pointer to one of the host's own chip sets, never a copy. The
  /// name is resolved from the saved sets so the row can say WHICH set, which
  /// is the whole point of a default — a bare chevron would hide it.
  String _chipSetSubtitle(AppProvider app) {
    final group = app.currentGroup;
    final id = group.defaultChipSetId;
    if (id == null || id.isEmpty) return 'Not set yet';
    final name = app.savedChipSets
        .where((s) => s.id == id)
        .map((s) => s.name)
        .firstOrNull;
    // A pointer at a set this device cannot see still points somewhere: say so
    // rather than pretending the group has no default.
    return name ?? 'A chip set from your account';
  }
}

/// §B9 table settings: the count that triggers a split and whether seating
/// generation defaults to fully random. Stored on the group, so it is
/// re-seeded from [TableSettings] and only written when the host presses Save.
class _TableSettingsCard extends StatelessWidget {
  const _TableSettingsCard({
    required this.draft,
    required this.dirty,
    required this.canEdit,
    required this.onChanged,
    required this.onSave,
  });

  final TableSettings draft;
  final bool dirty;
  final bool canEdit;
  final ValueChanged<TableSettings> onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    // A value written before the 4–10 range existed would make the stepper
    // lie, so the display is clamped and the clamp is what gets saved.
    final seats = draft.maxPerTable.clamp(4, 10);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Table settings', style: _cardTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Every tournament in this group starts from these. A single game '
            'can still override them in Configure.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Row(
            icon: Icons.table_restaurant_outlined,
            title: 'Players per table',
            subtitle: '4 to 10 seats — above this the field splits',
            trailing: CountStepper(
              value: seats,
              min: 4,
              max: 10,
              suffix: 'seats',
              semanticLabel: 'Players per table',
              onChanged: canEdit
                  ? (v) => onChanged(draft.copyWith(maxPerTable: v))
                  // A stepper with no listener still renders and still
                  // dims its arrows, which is how the row says "yours" is not
                  // "theirs" without a separate disabled style to keep in sync.
                  : (_) {},
            ),
          ),
          const _Divider(),
          _Row(
            icon: Icons.shuffle,
            title: 'Randomise seats by default',
            subtitle: 'Seating generation starts fully random',
            trailing: AppToggle(
              value: draft.randomizeByDefault,
              label: 'Randomise seats by default',
              onChanged: canEdit
                  ? (v) => onChanged(draft.copyWith(randomizeByDefault: v))
                  : (_) {},
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!canEdit)
            const AppAlertBanner(
              type: AppAlertType.info,
              message: 'Only the group owner can change the table settings. '
                  'Hand over ownership from Members to take this on.',
            )
          else
            AppButton(
              fullWidth: true,
              size: AppButtonSize.lg,
              variant: AppButtonVariant.secondary,
              onPressed: dirty ? onSave : null,
              child: Text(dirty ? 'Save table settings' : 'Saved'),
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'The default in Settings only pre-fills a new group. Changing it '
            'here changes this group alone.',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

/// §B9 reports: each reported message with its reporter and time, and the
/// three ways a host can deal with it.
class _ReportsCard extends StatelessWidget {
  const _ReportsCard({required this.reports, required this.isOwner});

  final List<ChatReport> reports;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppProvider>();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Reports', style: _cardTitle)),
              AppBadge(
                label: '${reports.length}',
                variant: AppBadgeVariant.red,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Members reported these messages. Handling one tells the reporter '
            'the host has dealt with it.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final r in reports)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _Report(report: r, isOwner: isOwner, app: app),
            ),
        ],
      ),
    );
  }
}

class _Report extends StatelessWidget {
  const _Report({required this.report, required this.isOwner, required this.app});

  final ChatReport report;
  final bool isOwner;
  final AppProvider app;

  /// §B9: "Handling one tells the reporter 'The host has dealt with your
  /// report.'" The reporter is not in the room, so an in-app note addressed
  /// only to them is the only way the sentence reaches them.
  void _tellReporter() {
    app.pushNotification(
      AppNotification(
        id: 'report-handled-${report.id}',
        title: 'Your report was handled',
        body: 'The host has dealt with your report.',
        type: NotificationType.admin,
        link: RoutePaths.chat,
        read: false,
        timestamp: DateTime.now(),
        audience: [report.reporterId],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reporter = app.currentGroup.members
        .where((m) => m.id == report.reporterId)
        .map((m) => m.name)
        .firstOrNull;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.destructive.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${report.authorName} wrote',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(report.excerpt, style: AppTypography.bodySm),
          const SizedBox(height: AppSpacing.xs),
          // The closed-list reason the member picked (§E10 (2)), so the host
          // judges the message on the same wording every time. Conditional
          // because reports filed before the field existed have none.
          if (report.reason != null) ...[
            AppBadge(label: report.reason!, variant: AppBadgeVariant.red),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            'Reported by ${reporter ?? 'a member'} · '
            '${Formatters.relativeTime(report.createdAt)}'
            '${report.gameId != null ? ' · game chat' : ''}',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.danger,
                onPressed: () {
                  _tellReporter();
                  app.resolveReport(report, removeMessage: true);
                },
                child: const Text('Delete message'),
              ),
              // Owner-only, and not because the spec says so:
              // `removeMember` returns immediately for anyone else, so a
              // co-host would press this and be told nothing.
              if (isOwner)
                AppButton(
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.secondary,
                  onPressed: () {
                    _tellReporter();
                    app.removeMember(report.authorId);
                    app.resolveReport(report);
                  },
                  child: Text('Remove ${report.authorName} from the group'),
                ),
              AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.ghost,
                onPressed: () {
                  _tellReporter();
                  app.resolveReport(report);
                },
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// §B9 group code, and the re-roll that retires it.
class _GroupCodeCard extends StatelessWidget {
  const _GroupCodeCard({required this.joinCode, required this.canReroll});

  final String joinCode;

  /// Host-only: the re-roll retires the group's code for everyone.
  final bool canReroll;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Group code', style: _cardTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Anyone with this code sees the group\'s next game. Check-ins on '
            'the night still need your OK.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text(
              joinCode.isEmpty ? '——' : joinCode,
              style: AppTypography.monoXl.copyWith(
                letterSpacing: 6,
                color: joinCode.isEmpty
                    ? AppColors.mutedForeground
                    : AppColors.foreground,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            fullWidth: true,
            size: AppButtonSize.lg,
            variant: AppButtonVariant.secondary,
            onPressed:
                canReroll ? () => _reroll(context) : null,
            child: const Text('Re-roll the code'),
          ),
        ],
      ),
    );
  }

  /// B9: "the old code and link stop working at once", so the dialog says that
  /// rather than asking a bare "are you sure?" -- anyone who has already shared
  /// the old one is about to be holding a dead link.
  Future<void> _reroll(BuildContext context) async {
    final app = context.read<AppProvider>();
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Re-roll ${app.currentGroup.name}\'s code?',
          style: TextStyle(color: AppColors.foreground),
        ),
        content: Text(
          'The current code and its invite link stop working immediately. '
          'Anyone who already has the old one will not get in with it, and '
          'you will need to share the new code yourself.',
          style: AppTypography.bodySm.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Re-roll',
              style: TextStyle(
                color: AppColors.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await app.rerollGroupJoinCode();
    if (ok) return;
    // The code on screen is unchanged, so say why rather than leaving the host
    // wondering whether the tap registered.
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Could not re-roll the code. Try again.'),
      ),
    );
    router.go(RoutePaths.groupSettings);
  }
}

/// B9 "Delete group" — "confirm with the consequence".
///
/// Owner-only, and the only way an owner leaves a group. The card states what
/// goes: the nights, the chat and the standings, for every member, not just the
/// person tapping. That is why it asks for the group name rather than offering
/// a bare "are you sure?".
class _DeleteGroupCard extends StatelessWidget {
  const _DeleteGroupCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: AppColors.destructive.withValues(alpha: 0.30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('This group', style: _cardTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'As owner you cannot leave — deleting is the only way out, and it '
            'takes the group, its nights and its standings with it.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            fullWidth: true,
            size: AppButtonSize.lg,
            variant: AppButtonVariant.destructive,
            onPressed: () => _confirmDelete(context),
            child: const Text('Delete group'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final app = context.read<AppProvider>();
    final group = app.currentGroup;
    final router = GoRouter.of(context);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final nameCtrl = TextEditingController();
        return StatefulBuilder(
          builder: (context, setState) {
            final matches = nameCtrl.text.trim() == group.name;
            return AlertDialog(
              backgroundColor: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: AppColors.destructive.withValues(alpha: 0.30),
                ),
              ),
              title: Text(
                'Delete ${group.name}?',
                style: TextStyle(color: AppColors.foreground),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This cannot be undone. It removes the group for everyone, '
                    'along with its ${group.games.length} past '
                    'night${group.games.length == 1 ? '' : 's'}, its chat and '
                    'its standings. Members keep their own results.',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Type the group name to confirm',
                    style: AppTypography.bodySm,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: nameCtrl,
                    autofocus: true,
                    placeholder: group.name,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
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
                  onPressed: !matches
                      ? null
                      : () async {
                          Navigator.of(dialogContext).pop();
                          final ok = await app.deleteGroup();
                          if (!ok) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Could not delete the group. Try again.',
                                ),
                              ),
                            );
                            return;
                          }
                          router.go(RoutePaths.home);
                        },
                  child: Text(
                    'Delete permanently',
                    style: TextStyle(
                      color: AppColors.destructiveText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// §B9 "Leave group", for a host who is not the owner. Available because
/// `leaveGroup` exists and works for exactly this case.
class _LeaveGroupCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.read<AppProvider>();
    return AppCard(
      borderColor: AppColors.destructive.withValues(alpha: 0.30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('This group', style: _cardTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'You are a host here, not the owner, so you can leave. '
            'Hand over ownership first if you meant to stay.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            fullWidth: true,
            size: AppButtonSize.lg,
            variant: AppButtonVariant.danger,
            onPressed: () => _confirmLeave(context, app),
            child: const Text('Leave group'),
          ),
        ],
      ),
    );
  }

  /// §B9: "confirm with the consequence". Leaving is quiet and hard to undo —
  /// the only way back in is somebody sending the join code again — so the
  /// dialog says that rather than asking a bare "are you sure?".
  void _confirmLeave(BuildContext context, AppProvider app) {
    final group = app.currentGroup;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppColors.destructive.withValues(alpha: 0.30),
          ),
        ),
        title: Text(
          'Leave ${group.name}?',
          style: TextStyle(color: AppColors.foreground),
        ),
        content: Text(
          'You will stop seeing this group\'s games, chat and standings. Your '
          'results stay in the season table. The only way back in is somebody '
          'sending you the join code again.',
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
              app.leaveGroup();
              context.go(RoutePaths.home);
            },
            child: Text(
              'Leave group',
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

/// §B9: "Chip settings and standings belong to the group, not to one game —
/// set once here; every tournament in this group starts from them, and a
/// single game can still override them in Configure."
class _Principle extends StatelessWidget {
  const _Principle();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconTile(
            icon: Icons.lightbulb_outline,
            size: 40,
            tone: IconTileTone.soft,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Chip settings and standings belong to the group, not to one '
              'game — set once here; every tournament in this group starts '
              'from them, and a single game can still override them in '
              'Configure.',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotHost extends StatelessWidget {
  const _NotHost({required this.onBack, required this.message});

  final VoidCallback onBack;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      maxWidth: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(onBack: onBack, title: 'Group settings'),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                const IconTile(
                  icon: Icons.lock_outline,
                  size: 56,
                  tone: IconTileTone.neutral,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One settings row: glyph, title, what it does, and either a chevron or an
/// explicit "not available yet" pill.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.mutedForeground),
          const SizedBox(width: AppSpacing.md),
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
          const SizedBox(width: AppSpacing.sm),
          if (trailing != null)
            trailing!
          else
            Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.mutedForeground,
            ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: content,
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppColors.borderSubtle,
    );
  }
}

TextStyle get _cardTitle =>
    AppTypography.display(size: AppFontSizes.lg, weight: FontWeight.w600);
