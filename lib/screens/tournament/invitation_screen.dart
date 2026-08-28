import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/game.dart';
import '../../models/group.dart';
import '../../models/live_game.dart';
import '../../models/tournament.dart';
import '../../models/user.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon_label.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_toggle.dart';
import '../../widgets/code_display.dart';
import '../../widgets/rsvp_badge.dart';
import '../../widgets/chat_sheet.dart';

/// Invitation / RSVP page mirroring the web `InvitationPage`.
class InvitationScreen extends StatefulWidget {
  const InvitationScreen({super.key});

  @override
  State<InvitationScreen> createState() => _InvitationScreenState();
}

class _InvitationScreenState extends State<InvitationScreen> {
  bool _copied = false;

  Future<void> _copyLink(LiveGame game) async {
    await Clipboard.setData(
      ClipboardData(text: 'https://poker-night-tools.web.app/game/${game.publicCode}'),
    );
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _confirmCancelGame(
    BuildContext context,
    AppProvider app,
    LiveGame game,
  ) {
    showAppModal(
      context: context,
      title: 'Cancel game',
      child: _CancelGameForm(
        gameName: game.settings.name,
        onCancel: (reason) {
          app.cancelGame(reason);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final game = app.currentGame;
    final user = app.user;

    if (game == null) {
      return Center(
        child: Text(
          'No game selected.',
          style: AppTypography.bodySm.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
      );
    }

    final settings = game.settings;
    final group = app.currentGroup;
    final myPlayer = game.players.where((p) => p.id == user?.id).firstOrNull;
    final going = game.players
        .where((p) => p.rsvp != null && p.rsvp!.isGoing)
        .toList();
    final total = game.players
        .where((p) => p.rsvp != null && p.rsvp!.isGoing)
        .fold<int>(0, (s, p) => s + 1 + p.rsvp!.guestCount);
    // Categorized attendance (spec §4.4) — people and seats are both shown.
    final members = game.players.where((p) => !p.isGuest).toList();
    final confirmedMembers = members
        .where((p) => p.rsvp != null && p.rsvp!.isGoing)
        .toList();
    final confirmedMemberCount = confirmedMembers.length;
    final memberSeats = confirmedMembers.fold<int>(
      0,
      (s, p) => s + 1 + p.rsvp!.guestCount,
    );
    final claimedGuestSlots = game.guestSlots.where((s) => !s.available).length;
    final guestSlotsTotal = game.guestSlots.length;
    final maybeCount = members.where((p) => p.rsvp == Rsvp.maybe).length;
    final cantCount = members.where((p) => p.rsvp == Rsvp.cant).length;
    final noResponseCount = members.where((p) => p.rsvp == null).length;
    // Private addresses are hidden until the viewer is confirmed (11-015).
    final showAddress =
        !settings.locationPrivate ||
        (app.isAdmin) ||
        (myPlayer?.confirmed ?? false);

    return AppPage(
      maxWidth: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PremiumEventHeader(
            game: game,
            showAddress: showAddress,
            hostName: _hostName(app.currentGroup),
            onEdit: user?.isAdmin == true
                ? () => _openEditModal(context, app, game)
                : null,
          ),
          // §10.4: prominent display of recent event changes so members see
          // updated values without digging through chat or audit history.
          if (game.changeLog.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              borderColor: AppColors.primary.withValues(alpha: 0.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ Event updated',
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final entry in game.changeLog.reversed.take(3))
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        entry,
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          _ContextualMainButton(game: game, user: user, myPlayer: myPlayer),
          // Admin-only: where the structure stands. The AI estimate unlocks
          // 30 minutes before start (client rule) — before that the group is
          // still deciding who is coming.
          if (user?.isAdmin == true &&
              game.status != LiveGameStatus.completed &&
              game.status != LiveGameStatus.cancelled) ...[
            const SizedBox(height: AppSpacing.sm),
            _StructureStatusCard(game: game),
          ],
          if (user?.isAdmin == true &&
              game.status != LiveGameStatus.completed &&
              game.status != LiveGameStatus.cancelled) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              fullWidth: true,
              size: AppButtonSize.xl,
              variant: AppButtonVariant.danger,
              onPressed: () => _confirmCancelGame(context, app, game),
              child: const Text('Cancel Game'),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
          // Attendance summary (spec §4.4) — people and seats
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'Expected: $memberSeats players',
                      style: AppTypography.bodySm.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      height: 24,
                      child: Row(
                        children: [
                          for (
                            var i = 0;
                            i < confirmedMembers.length && i < 5;
                            i++
                          )
                            Align(
                              widthFactor: 0.7,
                              child: AppAvatar(
                                name: confirmedMembers[i].name,
                                size: AppAvatarSize.sm,
                              ),
                            ),
                          if (confirmedMembers.length > 5)
                            Align(
                              widthFactor: 0.7,
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: AppColors.border,
                                child: Text(
                                  '+${confirmedMembers.length - 5}',
                                  style: AppTypography.monoXs,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _AttendanceRow(
                  label: 'Confirmed members',
                  value: '$confirmedMemberCount people',
                  highlight: true,
                ),
                _AttendanceRow(
                  label: 'Confirmed guest slots',
                  value: guestSlotsTotal > 0
                      ? '$claimedGuestSlots of $guestSlotsTotal claimed'
                      : '0',
                  highlight: true,
                ),
                _AttendanceRow(label: 'Maybe', value: '$maybeCount'),
                _AttendanceRow(label: 'Can\u2019t come', value: '$cantCount'),
                _AttendanceRow(label: 'No response', value: '$noResponseCount'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Event-day preparation checklist (spec §4.6) — admin only, pre-live.
          if (user?.isAdmin == true &&
              game.status != LiveGameStatus.running &&
              game.status != LiveGameStatus.paused &&
              game.status != LiveGameStatus.finaltable &&
              game.status != LiveGameStatus.completed &&
              game.status != LiveGameStatus.cancelled) ...[
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              borderColor: AppColors.primary.withValues(alpha: 0.2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Event-day checklist',
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Walk through preparation in order — no need to remember the sequence.',
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _ChecklistRow(
                    label: 'Open check-in',
                    done:
                        (game.status == LiveGameStatus.checkin ||
                            game.status == LiveGameStatus.ready) ||
                        game.players.any((p) => p.checkedIn),
                    actionLabel: 'Open',
                    onAction: () => context.go(RoutePaths.checkIn),
                  ),
                  _ChecklistRow(
                    label: 'Generate structure estimate',
                    done:
                        game.structure.levels.isNotEmpty &&
                        game.structureConfirmed,
                    actionLabel: game.structure.levels.isNotEmpty
                        ? 'Review'
                        : 'Generate',
                    onAction: () => context.go(RoutePaths.structureReview),
                  ),
                  _ChecklistRow(
                    label: 'Confirm seating (at check-in)',
                    done: game.seatingConfirmed,
                    actionLabel: 'Seating',
                    onAction: () => context.go(RoutePaths.checkIn),
                  ),
                  _ChecklistRow(
                    label: 'Start the tournament',
                    done:
                        game.status == LiveGameStatus.running ||
                        game.status == LiveGameStatus.paused,
                    actionLabel: 'Dashboard',
                    onAction: () => context.go(RoutePaths.adminDashboard),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          // My RSVP

          // Share codes
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Share with guests',
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                CodeDisplay(code: game.publicCode, label: 'Game code'),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    AppButton(
                      size: AppButtonSize.sm,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => _copyLink(game),
                      child: _copied
                          ? AppIconLabel(
                              label: 'Link copied',
                              icon: Icons.check_circle,
                              color: AppColors.success,
                            )
                          : const Text('Copy link'),
                    ),
                    AppButton(
                      size: AppButtonSize.sm,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => showAppLinkModal(context, game),
                      child: const Text('Show QR code'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Guests open the link, choose who invited them, select their guest slot and request check-in. No account needed.',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Responses
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Responses',
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final p in game.players.where((p) => !p.isGuest))
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        AppAvatar(name: p.name, size: AppAvatarSize.sm),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(p.name, style: AppTypography.bodySm),
                        ),
                        RSVPBadge(rsvp: p.rsvp),
                      ],
                    ),
                  ),
                if (going.isNotEmpty) ...[
                  Divider(color: AppColors.border),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Text(
                        'Total confirmed (incl. guests)',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$total',
                        style: AppTypography.monoXs.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Guest slots (07-014) — the persisted named seats for "Going +N"
          // RSVPs, shown with their current status so the host can see which
          // guest seats are still open.
          if (game.guestSlots.isNotEmpty) ...[
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Guest seats',
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final slot in game.guestSlots)
                    Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_seat_outlined,
                            size: 16,
                            color: AppColors.icon,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              '${_memberName(game, slot.inviterId)}\'s Guest ${slot.slot}'
                              '${slot.guestName != null ? ' — ${slot.guestName}' : ''}',
                              style: AppTypography.bodySm,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _GuestSlotBadge(status: slot.status),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Chat & Polls — visible to members only (spec §1: "Event rules,
          // own RSVP, chat, polls"; guests see none of these).
          if (!app.isGuest) ...[
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.icon),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Chat & Polls',
                        style: AppTypography.bodySm.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (game.chat.isNotEmpty)
                        AppBadge(
                          label: '${game.chat.length}',
                          variant: AppBadgeVariant.green,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    fullWidth: true,
                    size: AppButtonSize.sm,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => ChatSheet.show(context, game.id),
                    child: const Text('Open chat'),
                  ),
                  if (group.polls.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    for (final poll in group.polls.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                poll.question,
                                style: AppTypography.bodySm.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                '${poll.totalVotes} vote${poll.totalVotes == 1 ? '' : 's'}${poll.closed ? ' · closed' : ''}',
                                style: AppTypography.bodyXs.copyWith(
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Admin actions
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.label,
    required this.value,
    this.valueColor,
    this.mono = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: mono
                ? AppTypography.monoSm.copyWith(
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? AppColors.foreground,
                  )
                : AppTypography.bodySm.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

String _memberName(LiveGame game, String id) {
  for (final p in game.players) {
    if (p.id == id) return p.name;
  }
  return 'Member';
}

/// The group owner's display name — the host of every event in the group.
String _hostName(Group? group) {
  if (group == null) return 'the host';
  for (final m in group.members) {
    if (m.id == group.ownerId) return m.name;
  }
  return group.members.isNotEmpty ? group.members.first.name : 'the host';
}

/// Admin-only card describing the state of the AI structure estimate and
/// offering the single relevant action (client rule: the estimate is
/// generated ~30 minutes before start, from the RSVP attendance).
class _StructureStatusCard extends StatelessWidget {
  const _StructureStatusCard({required this.game});

  final LiveGame game;

  @override
  Widget build(BuildContext context) {
    final start = game.settings.scheduledStart;
    final unlockAt = start?.subtract(const Duration(minutes: 30));
    String hhmm(DateTime dt) =>
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    final hasStructure = game.structure.levels.isNotEmpty;
    final reviewOpen = game.structureReviewOpen;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      borderColor: AppColors.primary.withValues(alpha: 0.25),
      child: Row(
        children: [
          Icon(
            hasStructure ? Icons.check_circle_outline : Icons.auto_awesome,
            size: 22,
            color: hasStructure ? AppColors.success : AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasStructure
                      ? 'Structure generated for ${game.settings.players} players'
                            '${game.structureConfirmed ? ' — confirmed' : ''}'
                      : (reviewOpen
                            ? 'Structure ready to generate'
                            : 'Structure unlocks 30 min before start'),
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasStructure
                      ? 'Stacks, blinds, levels and chips are set. Review or edit any time before the game; stacks freeze when play starts.'
                      : (reviewOpen
                            ? 'Attendance is final enough — let the AI calculate stacks, blinds and levels from the Going / Going +N answers.'
                            : (unlockAt != null
                                  ? 'The AI will estimate the structure at ${hhmm(unlockAt)}, based on who answers the invitation.'
                                  : 'The AI will estimate the structure 30 minutes before start, based on attendance.')),
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          AppButton(
            size: AppButtonSize.sm,
            variant: hasStructure
                ? AppButtonVariant.secondary
                : AppButtonVariant.primary,
            onPressed: () => context.go(RoutePaths.structureReview),
            child: Text(hasStructure ? 'Review' : 'Generate'),
          ),
        ],
      ),
    );
  }
}

class _GuestSlotBadge extends StatelessWidget {
  const _GuestSlotBadge({required this.status});

  final GuestSlotStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, variant) = switch (status) {
      GuestSlotStatus.unclaimed => ('Free', AppBadgeVariant.muted),
      GuestSlotStatus.reserved => ('Reserved', AppBadgeVariant.accent),
      GuestSlotStatus.checkInRequested => (
        'Check-in requested',
        AppBadgeVariant.accent,
      ),
      GuestSlotStatus.checkedIn => ('Checked in', AppBadgeVariant.green),
      GuestSlotStatus.cancelled => ('Cancelled', AppBadgeVariant.red),
    };
    return AppBadge(label: label, variant: variant, border: true);
  }
}

/// Admin "Review RSVPs" modal (audit fix E4 — the button used to navigate to
/// Check-in). Shows the live attendance breakdown plus every member's answer.
void _showRsvpListModal(BuildContext context, LiveGame game) {
  final members = game.players.where((p) => !p.isGuest).toList();
  final going = members
      .where((p) => p.rsvp != null && p.rsvp!.isGoing)
      .toList();
  final seats = going.fold<int>(0, (s, p) => s + 1 + p.rsvp!.guestCount);
  final maybe = members.where((p) => p.rsvp == Rsvp.maybe).length;
  final cant = members.where((p) => p.rsvp == Rsvp.cant).length;
  final none = members.where((p) => p.rsvp == null).length;

  showAppModal(
    context: context,
    title: 'RSVPs — ${game.settings.name}',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.md,
          children: [
            AppBadge(
              label: '$seats expected',
              variant: AppBadgeVariant.green,
              border: true,
            ),
            AppBadge(
              label: '${going.length} going',
              variant: AppBadgeVariant.accent,
              border: true,
            ),
            if (maybe > 0)
              AppBadge(
                label: '$maybe maybe',
                variant: AppBadgeVariant.gold,
                border: true,
              ),
            if (cant > 0)
              AppBadge(
                label: '$cant can’t come',
                variant: AppBadgeVariant.muted,
                border: true,
              ),
            if (none > 0)
              AppBadge(
                label: '$none no response',
                variant: AppBadgeVariant.red,
                border: true,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Divider(color: AppColors.border),
        const SizedBox(height: AppSpacing.sm),
        for (final p in members)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                AppAvatar(name: p.name, size: AppAvatarSize.sm),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(p.name, style: AppTypography.bodySm)),
                RSVPBadge(rsvp: p.rsvp),
              ],
            ),
          ),
      ],
    ),
  );
}

void _openEditModal(BuildContext context, AppProvider app, LiveGame game) {
  showAppModal(
    context: context,
    title: 'Edit event details',
    maxWidth: 520,
    child: _EditEventForm(
      settings: game.settings,
      onSave: (next, {bool clearRsvps = false}) {
        app.updateEventSettings(next, clearRsvps: clearRsvps);
        Navigator.of(context).pop();
      },
    ),
  );
}

/// Admin form to edit an existing event's details. Changes are audited and
/// members are notified via [AppProvider.updateEventSettings] (checklist §10.4).
class _EditEventForm extends StatefulWidget {
  const _EditEventForm({required this.settings, required this.onSave});

  final GameSettings settings;
  final void Function(GameSettings, {bool clearRsvps}) onSave;

  @override
  State<_EditEventForm> createState() => _EditEventFormState();
}

class _EditEventFormState extends State<_EditEventForm> {
  late final TextEditingController _name;
  late final TextEditingController _date;
  late final TextEditingController _time;
  late final TextEditingController _location;
  late final TextEditingController _buyIn;
  late final TextEditingController _rebuyCost;
  late final TextEditingController _addOnCost;
  late final TextEditingController _koAmount;
  late bool _locationPrivate;
  late double _duration;
  late bool _rebuys;
  late bool _rebuyUnlimited;
  late int _rebuysClose;
  late bool _reEntry;
  late bool _addOn;
  late int _addOnClose;
  late bool _koEnabled;
  late AntePreference _antePreference;
  late int _anteAfterLevel;
  late final TextEditingController _orgPct;

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _name = TextEditingController(text: s.name);
    _date = TextEditingController(text: s.date);
    _time = TextEditingController(text: s.time);
    _location = TextEditingController(text: s.location);
    _buyIn = TextEditingController(text: '${s.buyIn}');
    _rebuyCost = TextEditingController(text: s.rebuyCost?.toString() ?? '');
    _addOnCost = TextEditingController(text: s.addOnCost?.toString() ?? '');
    _koAmount = TextEditingController(text: '${s.koAmount}');
    _locationPrivate = s.locationPrivate;
    _duration = s.durationHours;
    _rebuys = s.rebuys;
    _rebuyUnlimited = s.rebuysCloseLevel >= 6;
    _rebuysClose = s.rebuysCloseLevel;
    _reEntry = s.reEntry;
    _addOn = s.addOn;
    _addOnClose = s.addOnCloseLevel;
    _koEnabled = s.koEnabled;
    _antePreference = s.antePreference;
    _anteAfterLevel = s.anteAfterLevel;
    _orgPct = TextEditingController(text: '${s.organizerPct}');
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _date,
      _time,
      _location,
      _buyIn,
      _rebuyCost,
      _addOnCost,
      _koAmount,
      _orgPct,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final s = widget.settings;
    // Validate required fields before saving.
    final name = _name.text.trim();
    if (name.isEmpty) {
      showAppModal(
        context: context,
        title: 'Validation Error',
        child: const Text('Event name cannot be empty.'),
      );
      return;
    }
    final buyInVal = num.tryParse(_buyIn.text) ?? 0;
    if (buyInVal <= 0) {
      showAppModal(
        context: context,
        title: 'Validation Error',
        child: const Text('Buy-in must be a positive number.'),
      );
      return;
    }
    final newDate = _date.text.trim().isEmpty ? s.date : _date.text.trim();
    final newTime = _time.text.trim().isEmpty ? s.time : _time.text.trim();
    // Validate date format if changed.
    if (newDate != s.date) {
      final parsed = DateTime.tryParse(newDate);
      if (parsed == null) {
        showAppModal(
          context: context,
          title: 'Validation Error',
          child: const Text('Invalid date format (YYYY-MM-DD).'),
        );
        return;
      }
    }
    // Player count is intentionally not editable here — it is derived from
    // who RSVPs (Going / Going +1/+2) and who actually checks in.
    final newS = s.copyWith(
      name: name,
      date: newDate,
      time: newTime,
      location: _location.text.trim(),
      buyIn: num.tryParse(_buyIn.text)?.toInt() ?? s.buyIn,
      locationPrivate: _locationPrivate,
      durationHours: _duration,
      rebuys: _rebuys,
      rebuysCloseLevel: _rebuys ? _rebuysClose : 0,
      reEntry: _reEntry,
      addOn: _addOn,
      addOnCloseLevel: _addOnClose,
      koEnabled: _koEnabled,
      koAmount: num.tryParse(_koAmount.text)?.toInt() ?? s.koAmount,
      rebuyCost: _rebuys ? (num.tryParse(_rebuyCost.text)?.toInt()) : null,
      addOnCost: _addOn ? (num.tryParse(_addOnCost.text)?.toInt()) : null,
      antePreference: _antePreference,
      anteAfterLevel: _anteAfterLevel,
      anteEnabled: _antePreference != AntePreference.none,
      anteStyle: _antePreference == AntePreference.individual
          ? AnteStyle.individual
          : AnteStyle.bigBlind,
      organizerPct: (int.tryParse(_orgPct.text.trim()) ?? s.organizerPct).clamp(
        0,
        100,
      ),
    );

    if (s.date != newDate || s.time != newTime) {
      showAppModal(
        context: context,
        title: 'Date or Time Changed',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'You have changed the scheduled date or time. Would you like to clear existing RSVPs so players must confirm they can still make it?',
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              variant: AppButtonVariant.destructive,
              onPressed: () {
                Navigator.pop(context);
                widget.onSave(newS, clearRsvps: true);
              },
              child: const Text('Clear RSVPs'),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              variant: AppButtonVariant.secondary,
              onPressed: () {
                Navigator.pop(context);
                widget.onSave(newS, clearRsvps: false);
              },
              child: const Text('Keep RSVPs'),
            ),
          ],
        ),
      );
    } else {
      widget.onSave(newS);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(controller: _name, label: 'Name'),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppTextField(controller: _date, label: 'Date'),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppTextField(controller: _time, label: 'Start time'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(controller: _location, label: 'Location (optional)'),
        const SizedBox(height: AppSpacing.sm),
        _ToggleRow(
          title: 'Keep address private',
          subtitle: 'Hidden on public views until check-in',
          value: _locationPrivate,
          onChanged: (v) => setState(() => _locationPrivate = v),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _buyIn,
          label: 'Buy-in',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.lg),
        Divider(color: AppColors.border),
        const SizedBox(height: AppSpacing.sm),
        _SegmentedPicker(
          label: 'Duration',
          options: const ['4h', '3h', '3.5h', '4.5h', '5h', '5.5h', '6h'],
          selected:
              '${_duration == _duration.roundToDouble() ? _duration.round() : _duration}h',
          onChanged: (v) {
            final val = v.replaceAll('h', '');
            setState(() => _duration = double.tryParse(val) ?? 4.0);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        _EditRow(
          title: 'Rebuys',
          subtitle: 'Players can re-enter after elimination',
          trailing: _SegmentedPicker(
            options: const ['Off', 'Limited', 'Unlimited'],
            selected: _rebuys
                ? (_rebuyUnlimited ? 'Unlimited' : 'Limited')
                : 'Off',
            onChanged: (v) => setState(() {
              if (v == 'Off') {
                _rebuys = false;
                _rebuyUnlimited = false;
              } else if (v == 'Limited') {
                _rebuys = true;
                _rebuyUnlimited = false;
              } else {
                _rebuys = true;
                _rebuyUnlimited = true;
                _rebuysClose = 6;
              }
            }),
          ),
        ),
        if (_rebuys && !_rebuyUnlimited)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              top: AppSpacing.sm,
            ),
            child: _SegmentedPicker(
              label: 'Close rebuys',
              options: const ['End L4', 'End L5', 'End L6', 'End L7', 'End L8'],
              selected: 'End L$_rebuysClose',
              onChanged: (v) => setState(
                () =>
                    _rebuysClose = int.tryParse(v.replaceAll('End L', '')) ?? 6,
              ),
            ),
          ),
        if (_rebuys && _rebuyUnlimited)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              top: AppSpacing.sm,
            ),
            child: Text(
              'Unlimited rebuys until the end of Level 6.',
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        if (_rebuys)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              top: AppSpacing.sm,
            ),
            child: AppTextField(
              controller: _rebuyCost,
              label: 'Rebuy price (optional)',
              keyboardType: TextInputType.number,
              placeholder: 'Default (${_buyIn.text})',
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        _ToggleRow(
          title: 'Re-entry',
          subtitle: 'Separate option — buy a new entry stack after elimination',
          value: _reEntry,
          onChanged: (v) => setState(() => _reEntry = v),
        ),
        const SizedBox(height: AppSpacing.sm),
        _EditRow(
          title: 'Add-on',
          subtitle: 'One per active player at rebuy close',
          trailing: _SegmentedPicker(
            options: const ['Yes', 'No'],
            selected: _addOn ? 'Yes' : 'No',
            onChanged: (v) => setState(() => _addOn = v == 'Yes'),
          ),
        ),
        if (_addOn) ...[
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              top: AppSpacing.sm,
            ),
            child: AppTextField(
              controller: _addOnCost,
              label: 'Add-on price (optional)',
              keyboardType: TextInputType.number,
              placeholder: 'Default (${_buyIn.text})',
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              top: AppSpacing.sm,
            ),
            child: _SegmentedPicker(
              label: 'Add-on available until',
              options: const ['End L4', 'End L5', 'End L6', 'End L7', 'End L8'],
              selected: 'End L$_addOnClose',
              onChanged: (v) => setState(
                () =>
                    _addOnClose = int.tryParse(v.replaceAll('End L', '')) ?? 6,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        _EditRow(
          title: 'KO bounty',
          subtitle: 'Side payment for eliminating a player',
          trailing: _SegmentedPicker(
            options: const ['Yes', 'No'],
            selected: _koEnabled ? 'Yes' : 'No',
            onChanged: (v) => setState(() => _koEnabled = v == 'Yes'),
          ),
        ),
        if (_koEnabled)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              top: AppSpacing.sm,
            ),
            child: AppTextField(
              controller: _koAmount,
              label: 'Bounty amount',
              keyboardType: TextInputType.number,
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        _EditRow(
          title: 'Ante',
          subtitle: 'How the ante is posted',
          trailing: _SegmentedPicker(
            options: const [
              'Recommended',
              'No ante',
              'Big blind',
              'Individual',
            ],
            selected: switch (_antePreference) {
              AntePreference.recommend => 'Recommended',
              AntePreference.none => 'No ante',
              AntePreference.bigBlind => 'Big blind',
              AntePreference.individual => 'Individual',
            },
            onChanged: (v) => setState(
              () => _antePreference = switch (v) {
                'No ante' => AntePreference.none,
                'Big blind' => AntePreference.bigBlind,
                'Individual' => AntePreference.individual,
                _ => AntePreference.recommend,
              },
            ),
          ),
        ),
        if (_antePreference != AntePreference.none)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              top: AppSpacing.sm,
            ),
            child: _SegmentedPicker(
              label: 'Activate ante',
              options: const [
                'After L4',
                'After L5',
                'After L6',
                'After L7',
                'After L8',
              ],
              selected: 'After L$_anteAfterLevel',
              onChanged: (v) => setState(
                () => _anteAfterLevel =
                    int.tryParse(v.replaceAll('After L', '')) ?? 6,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        _EditRow(
          title: 'Organizational costs',
          subtitle: 'Percentage (%) — admin only, never shown to players',
          trailing: SizedBox(
            width: 90,
            child: AppTextField(
              controller: _orgPct,
              label: '%',
              keyboardType: TextInputType.number,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Changing game details regenerates the structure estimate. '
          'All edits are recorded in the audit log and shared with members.',
          style: AppTypography.bodyXs.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          fullWidth: true,
          onPressed: _save,
          child: const Text('Save changes'),
        ),
      ],
    );
  }
}

class _EditRow extends StatelessWidget {
  const _EditRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w500,
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
          trailing,
        ],
      ),
    );
  }
}

class _SegmentedPicker extends StatelessWidget {
  const _SegmentedPicker({
    required this.options,
    required this.selected,
    required this.onChanged,
    this.label,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    Widget picker = Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final o in options)
          GestureDetector(
            onTap: () => onChanged(o),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: o == selected ? AppColors.primary : AppColors.secondary,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                o,
                style: AppTypography.bodyXs.copyWith(
                  color: o == selected
                      ? AppColors.foreground
                      : AppColors.mutedForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );

    if (label != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label!,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          picker,
        ],
      );
    }
    return picker;
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w500,
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
          AppToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

void showAppLinkModal(BuildContext context, LiveGame game) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (context) => Dialog(
      backgroundColor: AppColors.card,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Guest link',
              style: AppTypography.display(size: AppFontSizes.lg),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Real scannable QR code for the guest join link.
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: QrImageView(
                data: 'https://poker-night-tools.web.app/game/${game.publicCode}',
                version: QrVersions.auto,
                size: 200,
                gapless: false,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'https://poker-night-tools.web.app/game/${game.publicCode}',
              textAlign: TextAlign.center,
              style: AppTypography.monoSm.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Guests scan this to open the join page — no account needed.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              fullWidth: true,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodySm.copyWith(
                color: highlight
                    ? AppColors.foreground
                    : AppColors.mutedForeground,
                fontWeight: highlight ? FontWeight.w500 : null,
              ),
            ),
          ),
          Text(
            value,
            style: AppTypography.monoXs.copyWith(
              color: highlight
                  ? AppColors.foreground
                  : AppColors.mutedForeground,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.label,
    required this.done,
    this.actionLabel,
    this.onAction,
  });

  final String label;
  final bool done;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: done ? AppColors.success : AppColors.mutedForeground,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodySm.copyWith(
                color: done ? AppColors.foreground : AppColors.mutedForeground,
                fontWeight: done ? FontWeight.w500 : null,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null && !done) ...[
            AppButton(
              size: AppButtonSize.sm,
              variant: AppButtonVariant.secondary,
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContextualMainButton extends StatelessWidget {
  const _ContextualMainButton({
    required this.game,
    required this.user,
    required this.myPlayer,
  });

  final LiveGame game;
  final AppUser? user;
  final Player? myPlayer;

  @override
  Widget build(BuildContext context) {
    if (user == null) return const SizedBox.shrink();
    final app = context.read<AppProvider>();
    final isAdmin = user!.isAdmin;

    if (isAdmin) {
      switch (game.status) {
        case LiveGameStatus.draft:
          return AppButton(
            fullWidth: true,
            size: AppButtonSize.xl,
            onPressed: () => _openEditModal(context, app, game),
            child: const Text('Review RSVPs'),
          );
        case LiveGameStatus.published:
          // Audit fix (E4): the button used to jump to Check-in. It now
          // actually shows the RSVP list (spec §4.4 "Review RSVPs").
          return AppButton(
            fullWidth: true,
            size: AppButtonSize.xl,
            onPressed: () => _showRsvpListModal(context, game),
            child: const Text('Review RSVPs'),
          );
        case LiveGameStatus.checkin:
        case LiveGameStatus.ready:
          final checkedInCount = game.players
              .where((p) => p.checkedIn && p.confirmed)
              .length;
          final seatingConfirmed = game.seatingConfirmed;
          if (checkedInCount >= 2 && seatingConfirmed) {
            return AppButton(
              fullWidth: true,
              size: AppButtonSize.xl,
              onPressed: () {
                app.updateEventSettings(
                  game.settings.copyWith(players: checkedInCount),
                );
                app.updateGameStatus(LiveGameStatus.running);
                context.go(RoutePaths.adminDashboard);
              },
              child: const Text('Start Tournament'),
            );
          } else {
            return AppButton(
              fullWidth: true,
              size: AppButtonSize.xl,
              onPressed: () => context.go(RoutePaths.checkIn),
              child: const Text('Open Check-in'),
            );
          }
        case LiveGameStatus.running:
        case LiveGameStatus.paused:
        case LiveGameStatus.finaltable:
          return AppButton(
            fullWidth: true,
            size: AppButtonSize.xl,
            onPressed: () => context.go(RoutePaths.adminDashboard),
            child: const Text('Manage Tournament'),
          );
        case LiveGameStatus.rebuypause:
          return AppButton(
            fullWidth: true,
            size: AppButtonSize.xl,
            onPressed: () => context.go(RoutePaths.rebuySettlement),
            child: const Text('Complete Rebuy & Add-on Break'),
          );
        case LiveGameStatus.completed:
          return AppButton(
            fullWidth: true,
            size: AppButtonSize.xl,
            onPressed: () => context.go(RoutePaths.resultPodium),
            child: const Text('View Results'),
          );
        case LiveGameStatus.cancelled:
          return AppButton(
            fullWidth: true,
            size: AppButtonSize.xl,
            onPressed: null,
            child: const Text('Tournament Cancelled'),
          );
      }
    } else {
      // Member flow
      if (game.status == LiveGameStatus.completed) {
        return AppButton(
          fullWidth: true,
          size: AppButtonSize.xl,
          onPressed: () => context.go(RoutePaths.resultPodium),
          child: const Text('View Results'),
        );
      }

      final isRunning =
          game.status == LiveGameStatus.running ||
          game.status == LiveGameStatus.paused ||
          game.status == LiveGameStatus.finaltable ||
          game.status == LiveGameStatus.rebuypause;
      if (isRunning) {
        return AppButton(
          fullWidth: true,
          size: AppButtonSize.xl,
          onPressed: () => context.go(RoutePaths.playerLive),
          child: const Text('Open Live Tournament'),
        );
      }

      final p = myPlayer;
      if (p != null) {
        if (p.checkedIn && p.confirmed) {
          final seated =
              game.players
                  .where((q) => q.table == p.table && q.seat > 0)
                  .toList()
                ..sort((a, b) => a.seat.compareTo(b.seat));
          return AppButton(
            fullWidth: true,
            size: AppButtonSize.xl,
            variant: AppButtonVariant.secondary,
            onPressed: () => showAppModal(
              context: context,
              title: 'Your Seat Assignment',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Text(
                      'Table ${p.table} · Seat ${p.seat}',
                      style: AppTypography.display(
                        size: AppFontSizes.xxxl,
                        weight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Divider(color: AppColors.border),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'At your table',
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final q in seated)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          AppAvatar(name: q.name, size: AppAvatarSize.sm),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              q.name,
                              style: AppTypography.bodySm.copyWith(
                                fontWeight: q.id == p.id
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          Text(
                            'Seat ${q.seat}',
                            style: AppTypography.monoXs.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            child: const Text('View My Seat'),
          );
        } else if (p.checkedIn && !p.confirmed) {
          return AppButton(
            fullWidth: true,
            size: AppButtonSize.xl,
            variant: AppButtonVariant.secondary,
            onPressed: null,
            child: const Text('Waiting for Confirmation'),
          );
        } else if ((game.status == LiveGameStatus.checkin ||
            game.status == LiveGameStatus.ready)) {
          return AppButton(
            fullWidth: true,
            size: AppButtonSize.xl,
            onPressed: () => app.requestCheckIn(p.id),
            child: const Text('Check In'),
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your RSVP',
                style: AppTypography.bodySm.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final opt in const [
                      Rsvp.going,
                      Rsvp.goingPlus1,
                      Rsvp.goingPlus2,
                      Rsvp.goingPlus3,
                      Rsvp.goingPlus4,
                      Rsvp.maybe,
                      Rsvp.cant,
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: _RsvpChip(
                          label: opt.label,
                          active: p.rsvp == opt,
                          enabled: !app.rsvpCutoffPassed,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            app.setRSVP(opt);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        }
      }
    }
    return const SizedBox.shrink();
  }
}

class _CancelGameForm extends StatefulWidget {
  const _CancelGameForm({required this.gameName, required this.onCancel});

  final String gameName;
  final ValueChanged<String> onCancel;

  @override
  State<_CancelGameForm> createState() => _CancelGameFormState();
}

class _CancelGameFormState extends State<_CancelGameForm> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reason = _reason.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Cancelling ${widget.gameName} stops the timer and removes it from live view. '
          'Members are notified and a reason is recorded in the audit log.',
          style: AppTypography.bodySm.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _reason,
          label: 'Reason (required)',
          hint: 'e.g. venue closed, not enough players',
          maxLines: 2,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: AppButton(
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Keep tournament'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppButton(
                variant: AppButtonVariant.danger,
                onPressed: reason.isEmpty
                    ? null
                    : () => widget.onCancel(reason),
                child: const Text('Cancel tournament'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PremiumEventHeader extends StatelessWidget {
  final LiveGame game;
  final bool showAddress;
  final String hostName;
  final VoidCallback? onEdit;

  const _PremiumEventHeader({
    required this.game,
    required this.showAddress,
    required this.hostName,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final settings = game.settings;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppBackButton(onTap: () => context.go(RoutePaths.group)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('♠️', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      settings.name,
                      style: AppTypography.display(
                        size: AppFontSizes.xxxl,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: AppColors.mutedForeground,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          settings.date,
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: AppColors.mutedForeground,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          settings.time,
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: AppColors.mutedForeground,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          showAddress
                              ? settings.location
                              : 'Address shared at check-in',
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppBadge(
                    label: game.status.name.toUpperCase(),
                    variant: game.status.isActiveLive
                        ? AppBadgeVariant.accent
                        : AppBadgeVariant.muted,
                  ),
                  if (onEdit != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    IconButton(
                      onPressed: onEdit,
                      icon: Icon(
                        Icons.edit_outlined,
                        color: AppColors.mutedForeground,
                      ),
                      tooltip: 'Edit details',
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          // The inputs the admin provided when creating the game — everyone
          // in the group sees these (organizational costs stay admin-only).
          Wrap(
            runSpacing: AppSpacing.md,
            spacing: AppSpacing.lg,
            children: [
              _Detail(
                label: 'Buy-in',
                value: '${settings.buyIn}',
                valueColor: AppColors.primary,
                mono: true,
              ),
              if (settings.koEnabled)
                _Detail(
                  label: 'KO bounty',
                  value: '${settings.buyIn} + ${settings.koAmount}',
                  valueColor: AppColors.primary,
                  mono: true,
                ),
              _Detail(
                label: 'Duration',
                value:
                    '${settings.durationHours == settings.durationHours.roundToDouble() ? settings.durationHours.round() : settings.durationHours}h',
                mono: true,
              ),
              _Detail(
                label: 'Rebuys',
                value: settings.rebuys
                    ? 'Unlimited, until L${settings.rebuysCloseLevel} @ ${settings.effectiveRebuyCost}'
                    : 'None',
              ),
              _Detail(
                label: 'Add-on',
                value: settings.addOn
                    ? '@ ${settings.effectiveAddOnCost}, end of L${settings.addOnCloseLevel}'
                    : 'None',
              ),
              if (settings.anteEnabled)
                _Detail(
                  label: 'Ante',
                  value: settings.anteStyle.name == 'individual'
                      ? 'Individual, from L${settings.anteAfterLevel + 1}'
                      : 'Big blind, from L${settings.anteAfterLevel + 1}',
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            runSpacing: AppSpacing.sm,
            spacing: AppSpacing.lg,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 14,
                    color: AppColors.mutedForeground,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Hosted by $hostName',
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 14,
                    color: AppColors.mutedForeground,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    settings.rsvpDeadline == null
                        ? 'RSVPs close 1 hour before start'
                        : 'RSVPs close at ${settings.rsvpDeadline!.hour.toString().padLeft(2, '0')}:${settings.rsvpDeadline!.minute.toString().padLeft(2, '0')}',
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RsvpChip extends StatefulWidget {
  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;
  const _RsvpChip({
    required this.label,
    required this.active,
    this.enabled = true,
    required this.onTap,
  });

  @override
  State<_RsvpChip> createState() => _RsvpChipState();
}

class _RsvpChipState extends State<_RsvpChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => _controller.forward() : null,
      onTapUp: widget.enabled
          ? (_) {
              _controller.reverse();
              widget.onTap();
            }
          : null,
      onTapCancel: widget.enabled ? () => _controller.reverse() : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Opacity(
          opacity: widget.enabled ? 1.0 : 0.4,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: widget.active ? AppColors.primary : AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: widget.active ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Text(
              widget.label,
              style: AppTypography.bodySm.copyWith(
                color: widget.active
                    ? AppColors.primaryForeground
                    : AppColors.mutedForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
