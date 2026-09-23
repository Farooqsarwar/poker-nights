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
import '../../models/user.dart';
import '../../providers/app_provider.dart';
import '../../utils/event_settings_validation.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon_label.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/code_display.dart';
import '../../widgets/rsvp_badge.dart';
import '../../widgets/chat_sheet.dart';
import '../../widgets/app_alert_banner.dart';
import '../../widgets/glass_styles.dart';
import '../../widgets/event_day_checklist.dart';
import '../../widgets/event_settings_form.dart';
import '../../widgets/journey_progress.dart';
import '../../widgets/min_tap_target.dart';

/// Invitation / RSVP page mirroring the web `InvitationPage`.
class InvitationScreen extends StatefulWidget {
  const InvitationScreen({super.key});

  @override
  State<InvitationScreen> createState() => _InvitationScreenState();
}

class _InvitationScreenState extends State<InvitationScreen> {
  bool _copied = false;
  bool _tourShown = false;

  Future<void> _copyLink(LiveGame game) async {
    await Clipboard.setData(
      ClipboardData(
        text: 'https://poker-night-tools.web.app/game/${game.publicCode}',
      ),
    );
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _showAdminTutorialDialog(BuildContext context) {
    showAppModal(
      context: context,
      title: 'Next Steps',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Your tournament is created! Here is what to do next.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('1. Group members have been notified and can RSVP.'),
          const Text('2. Share the 4-digit code below with any guests.'),
          const Text(
            '3. When you are ready to start seating players, tap "Open Check-in".',
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            fullWidth: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () {
              context.read<AppProvider>().setAppTour(false);
              Navigator.of(context).pop();
            },
            child: const Text('Don\'t show this again'),
          ),
        ],
      ),
    );
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

    if (app.isAdmin &&
        app.showAppTour &&
        game != null &&
        (game.status == LiveGameStatus.draft ||
            game.status == LiveGameStatus.published ||
            game.status == LiveGameStatus.checkin ||
            game.status == LiveGameStatus.ready) &&
        !_tourShown) {
      _tourShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAdminTutorialDialog(context);
      });
    }

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
          // Pre-live journey — persistent header shown across the invitation,
          // structure and check-in screens (Task C). Tapping a step navigates
          // to the screen that owns it.
          JourneyProgress(
            game: game,
            currentRoute: RoutePaths.invitation,
            onStepTap: (step) => context.go(step.route),
          ),
          _PremiumEventHeader(
            game: game,
            showAddress: showAddress,
            hostName: _hostName(app.currentGroup),
            onEdit: app.isAdmin
                ? () => _openEditModal(context, app, game)
                : null,
          ),
          if (app.isAdmin && app.lastSaveError != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: AppAlertBanner(
                type: AppAlertType.error,
                message: app.lastSaveError!,
              ),
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

          if (user != null &&
              !app.isGuest &&
              game.status != LiveGameStatus.completed &&
              game.status != LiveGameStatus.cancelled &&
              (myPlayer == null ||
                  (!myPlayer.checkedIn && !myPlayer.isGuest))) ...[
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              glow: true,
              child: _RsvpSection(
                myPlayer:
                    myPlayer ??
                    Player(
                      id: user.id,
                      name: user.name,
                      isGuest: false,
                      rsvp: null,
                      checkedIn: false,
                      confirmed: false,
                      eliminated: false,
                      rebuys: 0,
                      hasAddOn: false,
                      knockouts: 0,
                      table: 0,
                      seat: 0,
                      active: true,
                    ),
                cutoffPassed: app.rsvpCutoffPassed,
                onRsvp: (rsvp) {
                  HapticFeedback.lightImpact();
                  // Spec §7.1: warn if reducing guest count would remove
                  // already-claimed or checked-in guest slots.
                  final currentRsvp = myPlayer?.rsvp;
                  final newGuestCount = rsvp?.guestCount ?? 0;
                  final currentGuestCount = currentRsvp?.guestCount ?? 0;
                  if (newGuestCount < currentGuestCount) {
                    final claimedSlots = game.guestSlots
                        .where(
                          (s) =>
                              s.inviterId == (myPlayer?.id ?? '') &&
                              s.slot > newGuestCount &&
                              !s.available,
                        )
                        .length;
                    final slotsToRemove = currentGuestCount - newGuestCount;
                    if (claimedSlots > 0 && slotsToRemove > 0) {
                      showAppModal(
                        context: context,
                        title: 'Reduce guest count?',
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'You have $claimedSlots claimed guest slot${claimedSlots == 1 ? '' : 's'}. '
                              'Reducing your response may remove a slot already reserved by a guest. '
                              'The admin will need to resolve any conflict.',
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.mutedForeground,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            Row(
                              children: [
                                Expanded(
                                  child: AppButton(
                                    variant: AppButtonVariant.secondary,
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('Keep current RSVP'),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: AppButton(
                                    variant: AppButtonVariant.danger,
                                    onPressed: () {
                                      app.setRSVP(rsvp);
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('Change anyway'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                      return;
                    }
                  }
                  app.setRSVP(rsvp);
                },
              ),
            ),
          ],
          // Admin-only: where the structure stands. The AI estimate unlocks
          // 30 minutes before start (client rule) — before that the group is
          // still deciding who is coming.
          if (app.isAdmin &&
              game.status != LiveGameStatus.completed &&
              game.status != LiveGameStatus.cancelled) ...[
            const SizedBox(height: AppSpacing.sm),
            _StructureStatusCard(game: game),
          ],
          if (app.isAdmin &&
              game.status != LiveGameStatus.completed &&
              game.status != LiveGameStatus.cancelled) ...[
            const SizedBox(height: AppSpacing.sm),
            // Danger zone — visually separated per spec §12.6 / §13.2.
            AppCard(
              borderColor: AppColors.destructive.withValues(alpha: 0.25),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Danger zone',
                          style: AppTypography.bodyXs.copyWith(
                            color: AppColors.destructiveText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          'Cancel this game — requires a reason.',
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
                    variant: AppButtonVariant.danger,
                    onPressed: () => _confirmCancelGame(context, app, game),
                    child: const Text('Cancel game'),
                  ),
                ],
              ),
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
          // Uses the shared [EventDayChecklist]; step 2 ("Open check-in")
          // auto-derives through the [onOpenCheckIn] action.
          if (app.isAdmin &&
              game.status != LiveGameStatus.running &&
              game.status != LiveGameStatus.paused &&
              game.status != LiveGameStatus.finaltable &&
              game.status != LiveGameStatus.completed &&
              game.status != LiveGameStatus.cancelled) ...[
            EventDayChecklist(
              game: game,
              onOpenCheckIn: () {
                if (game.status == LiveGameStatus.draft ||
                    game.status == LiveGameStatus.published) {
                  app.updateGameStatus(LiveGameStatus.checkin);
                }
                context.go(RoutePaths.checkIn);
              },
              onOpenTvMode: null,
              onTestVoice: null,
            ),
            // Start status (B4) — the old "Start the tournament" checklist row
            // only navigated; this is a status, not a button.
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(
                    app.startBlockedReason == null
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    size: 16,
                    color: app.startBlockedReason == null
                        ? AppColors.success
                        : AppColors.mutedForeground,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      app.startBlockedReason == null
                          ? 'Ready to start the tournament.'
                          : app.startBlockedReason!,
                      style: AppTypography.bodyXs.copyWith(
                        color: app.startBlockedReason == null
                            ? AppColors.success
                            : AppColors.foreground,
                        fontWeight: app.startBlockedReason == null
                            ? FontWeight.w600
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          // My RSVP

          // Share codes
          if (game.status != LiveGameStatus.cancelled) ...[
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
            if (myPlayer != null && (myPlayer.rsvp?.guestCount ?? 0) > 0) ...[
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Your guest slots',
                      style: AppTypography.bodySm.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (var i = 1; i <= myPlayer.rsvp!.guestCount; i++) ...[
                      Builder(
                        builder: (context) {
                          final guest = game.players
                              .where(
                                (p) =>
                                    p.isGuest &&
                                    p.inviterId == myPlayer.id &&
                                    p.guestSlot == i,
                              )
                              .firstOrNull;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$i',
                                    style: AppTypography.monoXs.copyWith(
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    guest?.name.isNotEmpty == true
                                        ? guest!.name
                                        : 'Unclaimed',
                                    style: AppTypography.bodySm.copyWith(
                                      color: guest != null
                                          ? AppColors.foreground
                                          : AppColors.mutedForeground,
                                    ),
                                  ),
                                ),
                                if (guest != null)
                                  AppBadge(
                                    label: guest.confirmed
                                        ? 'Confirmed'
                                        : 'Pending',
                                    variant: guest.confirmed
                                        ? AppBadgeVariant.green
                                        : AppBadgeVariant.muted,
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
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
                          color: AppColors.successText,
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
          // Admin RSVP review — every guest awaiting a decision, with
          // Accept / Decline. The event cannot move forward to check-in while
          // any guest is still pending (see [_ContextualMainButton]).
          if (app.isAdmin) ...[
            Builder(
              builder: (context) {
                final pendingGuests = game.players
                    .where(
                      (p) =>
                          p.isGuest && !p.confirmed && p.name.trim().isNotEmpty,
                    )
                    .toList();
                return AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  borderColor: pendingGuests.isNotEmpty
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Guest requests',
                            style: AppTypography.bodySm.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (pendingGuests.isNotEmpty)
                            AppBadge(
                              label: '${pendingGuests.length} to review',
                              variant: AppBadgeVariant.red,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (pendingGuests.isEmpty)
                        Text(
                          'No guests waiting. Everyone who requested a seat has been reviewed.',
                          style: AppTypography.bodyXs.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        )
                      else
                        for (final g in pendingGuests)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: Row(
                              children: [
                                AppAvatar(name: g.name, size: AppAvatarSize.sm),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(g.name, style: AppTypography.bodySm),
                                      Text(
                                        'Guest of ${_memberName(game, g.inviterId ?? '')}',
                                        style: AppTypography.bodyXs.copyWith(
                                          color: AppColors.mutedForeground,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                AppButton(
                                  size: AppButtonSize.sm,
                                  onPressed: () => app.confirmGuest(g.id),
                                  child: const Text('Accept'),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                AppButton(
                                  size: AppButtonSize.sm,
                                  variant: AppButtonVariant.danger,
                                  onPressed: () => app.rejectGuest(g.id),
                                  child: const Text('Decline'),
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
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
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 16,
                        color: AppColors.icon,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Chat',
                        style: AppTypography.bodySm.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Builder(
                        builder: (_) {
                          final count = app
                              .gameChatMessages(game.id)
                              .where((m) => !m.deleted)
                              .length;
                          if (count == 0) return const SizedBox.shrink();
                          return AppBadge(
                            label: '$count',
                            variant: AppBadgeVariant.green,
                          );
                        },
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
    return Container(
      width: 160,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        // `secondary` is white-with-alpha in most palettes, so overriding
        // its alpha turned these tiles into pale blocks with unreadable
        // labels on mobile. See Glass.solidTint.
        color: Glass.solidTint(AppColors.secondary),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: mono
                ? AppTypography.monoSm.copyWith(
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? AppColors.foreground,
                  )
                : AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
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
    final reviewOpen = (game.status == LiveGameStatus.ready);

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
                const SizedBox(height: AppSpacing.xxs),
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
/// Admins can long-press a member row to correct or reopen that member's RSVP
/// (User Flow §3.1).
void _showRsvpListModal(BuildContext context, AppProvider app, LiveGame game) {
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
            child: GestureDetector(
              onLongPress: app.isAdmin
                  ? () => _showAdminRsvpOverride(context, app, game, p)
                  : null,
              child: Row(
                children: [
                  AppAvatar(name: p.name, size: AppAvatarSize.sm),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text(p.name, style: AppTypography.bodySm)),
                  RSVPBadge(rsvp: p.rsvp),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          fullWidth: true,
          size: AppButtonSize.xl,
          onPressed: () {
            Navigator.of(context).pop();
            final app = context.read<AppProvider>();
            app.updateGameStatus(LiveGameStatus.checkin);
            context.go(RoutePaths.checkIn);
          },
          child: const Text('Open Check-in'),
        ),
      ],
    ),
  );
}

/// Admin correct-or-reopen for a single member's RSVP (User Flow §3.1).
void _showAdminRsvpOverride(
  BuildContext context,
  AppProvider app,
  LiveGame game,
  Player p,
) {
  final choices = <String, Rsvp?>{
    'Going': Rsvp.going,
    'Going +1': Rsvp.goingPlus1,
    'Going +2': Rsvp.goingPlus2,
    'Going +3': Rsvp.goingPlus3,
    'Going +4': Rsvp.goingPlus4,
    'Maybe': Rsvp.maybe,
    'Can’t come': Rsvp.cant,
  };
  showAppModal(
    context: context,
    title: p.name,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in choices.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppButton(
              variant: p.rsvp == entry.value
                  ? AppButtonVariant.secondary
                  : AppButtonVariant.ghost,
              onPressed: () {
                app.adminSetRSVP(p.id, entry.value, gameId: game.id);
                Navigator.of(context).pop();
              },
              child: Text(entry.key),
            ),
          ),
        AppButton(
          variant: p.rsvp == null
              ? AppButtonVariant.secondary
              : AppButtonVariant.ghost,
          onPressed: () {
            app.adminSetRSVP(p.id, null, gameId: game.id);
            Navigator.of(context).pop();
          },
          child: const Text('No response'),
        ),
        // Sections 3 and 28 -- hand this ONE night to somebody else.
        //
        // A host who is also playing is the bottleneck on every rebuy at their
        // own table; this is the way out of that. Scoped to this tournament:
        // an organizer gets the live controls and this game's private money,
        // and nothing at group level.
        //
        // Guests are excluded deliberately (decision D7): an organizer has to
        // be assignable, auditable and accountable, which needs an account
        // rather than a name in a slot.
        if (!p.isGuest) ...[
          const SizedBox(height: AppSpacing.lg),
          Divider(color: AppColors.border),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tournament organizer',
            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            game.isOrganizer(p.id)
                ? '${p.name} can run this tournament — rebuys, add-ons, '
                      'eliminations and seating. Nothing at group level, and '
                      'nothing in any other game.'
                : 'Let ${p.name} run this tournament for you. They get the '
                      'live controls for tonight only.',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            fullWidth: true,
            variant: game.isOrganizer(p.id)
                ? AppButtonVariant.destructive
                : AppButtonVariant.secondary,
            onPressed: () {
              app.setTournamentOrganizer(
                p.id,
                assigned: !game.isOrganizer(p.id),
              );
              Navigator.of(context).pop();
            },
            child: Text(
              game.isOrganizer(p.id)
                  ? 'Remove as organizer'
                  : 'Make organizer for this game',
            ),
          ),
        ],
      ],
    ),
  );
}

void _openEditModal(BuildContext context, AppProvider app, LiveGame game) {
  showAppModal(
    context: context,
    title: 'Edit event details',
    maxWidth: 520,
    child: _EditEventModalBody(
      settings: game.settings,
      onSave: (next, {bool clearRsvps = false}) {
        app.updateEventSettings(next, clearRsvps: clearRsvps);
        Navigator.of(context).pop();
      },
    ),
  );
}

/// Modal body for editing an existing event's details. Mounts the shared
/// [EventSettingsForm] (all four sections, organizational costs shown) and
/// owns the two things that form deliberately does not: the confirmation
/// prompt that clears RSVPs when the scheduled date or time changed, and the
/// legacy org-% ceiling for games saved under the old 0-100 rule.
///
/// The [initial] seeded into [EventSettingsForm] is the untouched
/// [GameSettings], never a draft; the parent tracks the draft via [onChanged].
class _EditEventModalBody extends StatefulWidget {
  const _EditEventModalBody({required this.settings, required this.onSave});

  final GameSettings settings;
  final void Function(GameSettings, {bool clearRsvps}) onSave;

  @override
  State<_EditEventModalBody> createState() => _EditEventModalBodyState();
}

class _EditEventModalBodyState extends State<_EditEventModalBody> {
  late GameSettings _draft;
  final DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _draft = widget.settings;
  }

  /// Mirrors the old `_EditEventForm._save()` RSVP-clearing rule: a changed
  /// date or time asks the host whether to clear existing RSVPs. Reads the
  /// incoming draft as emitted through [EventSettingsForm.onChanged].
  bool get _dateOrTimeChanged =>
      _draft.date != widget.settings.date ||
      _draft.time != widget.settings.time;

  /// Spec 7 caps organizer cost at 20%. This modal edits games that already
  /// exist, some created under the old 0-100 rule, so the ceiling is raised
  /// to whatever the game was saved with when that is higher. An existing
  /// figure is never silently rewritten — it can only be reduced.
  int get _orgPctCeiling =>
      widget.settings.organizerPct > GameSettings.maxOrganizerPct
          ? widget.settings.organizerPct
          : GameSettings.maxOrganizerPct;

  void _save() {
    // Gate on everything except the org %. A legacy game stored above 20 is
    // legal (it may only be reduced, see [_orgPctCeiling]), so flagging it
    // here would lock the host out of every other edit on that game.
    final blockers = {
      for (final entry in validateEventSettings(_draft, now: _now).entries)
        if (entry.key != 'orgPct') entry.key: entry.value,
    };
    if (blockers.isNotEmpty) {
      showAppModal(
        context: context,
        title: 'Validation Error',
        child: Text(blockers.values.first),
      );
      return;
    }
    if (_dateOrTimeChanged) {
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
                widget.onSave(_draft, clearRsvps: true);
              },
              child: const Text('Clear RSVPs'),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              variant: AppButtonVariant.secondary,
              onPressed: () {
                Navigator.pop(context);
                widget.onSave(_draft, clearRsvps: false);
              },
              child: const Text('Keep RSVPs'),
            ),
          ],
        ),
      );
      return;
    }
    widget.onSave(_draft);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EventSettingsForm(
          initial: widget.settings,
          // The four-section mount: details/chips/rules/money. `rules` is the
          // monolithic section covering rebuys+add-ons AND format, so this
          // paints every field exactly once. A plain `values.toSet()` would
          // also pull in the fine-grained `rebuys`/`format` section values
          // the creation wizard mounts, rendering the rules fields twice.
          sections: const {
            EventFormSection.details,
            EventFormSection.chips,
            EventFormSection.rules,
            EventFormSection.money,
          },
          showOrganizerPct: true,
          orgPctCeiling: _orgPctCeiling,
          onChanged: (draft) => _draft = draft,
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
                // Literal white, deliberately: a QR code needs a light quiet
                // zone and maximum contrast to scan.
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: QrImageView(
                data:
                    'https://poker-night-tools.web.app/game/${game.publicCode}',
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
    final isAdmin = app.isAdmin;

    if (isAdmin) {
      switch (game.status) {
        case LiveGameStatus.draft:
          return AppButton(
            fullWidth: true,
            size: AppButtonSize.xl,
            onPressed: () => _openEditModal(context, app, game),
            child: const Text('Edit Event'),
          );
        case LiveGameStatus.published:
          // Audit fix (E4): the button used to jump to Check-in. It now
          // actually shows the RSVP list (spec §4.4 "Review RSVPs").
          return AppButton(
            fullWidth: true,
            size: AppButtonSize.xl,
            onPressed: () => _showRsvpListModal(context, app, game),
            child: const Text('Review RSVPs'),
          );
        case LiveGameStatus.checkin:
        case LiveGameStatus.ready:
          // One start precondition (B5): [AppProvider.startBlockedReason] is
          // the single source of truth for why the tournament cannot start.
          // It doubles as the disabled label; when null the button folds the
          // final confirmed head-count in and starts the timer.
          final blocked = app.startBlockedReason;
          return AppButton(
            fullWidth: true,
            size: AppButtonSize.xl,
            onPressed: blocked == null ? app.startTournament : null,
            child: Text(blocked ?? 'Start Tournament'),
          );
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
        case LiveGameStatus.onBreak:
          return AppButton(
            fullWidth: true,
            size: AppButtonSize.xl,
            onPressed: () => context.go(RoutePaths.adminDashboard),
            child: const Text('Manage Tournament'),
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
      // Blocking states take priority (spec §12 / §9.1) — mirrors the
      // canonical `_memberAction` in main_button.dart. Without this the member
      // kept seeing "Check In" / "Your Seat Assignment" on a tournament the
      // host had already cancelled.
      if (game.status == LiveGameStatus.cancelled) {
        return const AppButton(
          fullWidth: true,
          size: AppButtonSize.xl,
          onPressed: null,
          child: Text('Event Cancelled'),
        );
      }
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
      // A member who joined the group after this game's roster was seeded
      // (or who never answered the invite) has no row in game.players yet —
      // p is null. They must still be able to check in once check-in is
      // open (main_button.dart's canonical logic treats me == null as
      // eligible too); falling through to SizedBox.shrink() here previously
      // hid the Check In action entirely for them.
      if (p == null &&
          !game.checkInClosed &&
          (game.status == LiveGameStatus.checkin ||
              game.status == LiveGameStatus.ready)) {
        return AppButton(
          fullWidth: true,
          size: AppButtonSize.xl,
          // requestCheckIn creates the roster row (Going + checked in) as a
          // single atomic write when none exists yet — do not also call
          // setRSVP here, which would race a second, independent write
          // against the same players.{uid} map (see requestCheckIn).
          onPressed: () => app.requestCheckIn(user!.id),
          child: const Text('Check In'),
        );
      }
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
        } else if (!game.checkInClosed &&
            (game.status == LiveGameStatus.checkin ||
                game.status == LiveGameStatus.ready)) {
          return AppButton(
            fullWidth: true,
            size: AppButtonSize.xl,
            onPressed: () => app.requestCheckIn(p.id),
            child: const Text('Check In'),
          );
        }
      }
      return const SizedBox.shrink();
    }
  }
}

/// The full member RSVP section: three status chips (Going / Maybe / Can't)
/// and, when "Going" is selected, an inline guest-count stepper (0–4).
/// Spec §4.3: guest count is part of the Going answer, not a separate chip.
class _RsvpSection extends StatefulWidget {
  const _RsvpSection({
    required this.myPlayer,
    required this.cutoffPassed,
    required this.onRsvp,
  });

  final Player myPlayer;
  final bool cutoffPassed;
  final void Function(Rsvp?) onRsvp;

  @override
  State<_RsvpSection> createState() => _RsvpSectionState();
}

class _RsvpSectionState extends State<_RsvpSection> {
  Rsvp _rsvpForGuestCount(int guests) => switch (guests) {
    1 => Rsvp.goingPlus1,
    2 => Rsvp.goingPlus2,
    3 => Rsvp.goingPlus3,
    4 => Rsvp.goingPlus4,
    _ => Rsvp.going,
  };

  bool get _isGoing {
    final r = widget.myPlayer.rsvp;
    return r != null && r.isGoing;
  }

  int get _currentGuestCount => widget.myPlayer.rsvp?.guestCount ?? 0;

  @override
  Widget build(BuildContext context) {
    final current = widget.myPlayer.rsvp;
    final enabled = !widget.cutoffPassed;
    final lastError = context.select<AppProvider, String?>(
      (a) => a.lastRsvpError,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.cutoffPassed)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: AppAlertBanner(
              type: AppAlertType.warning,
              message: 'RSVP is closed — responses can no longer be changed.',
            ),
          ),
        Text(
          'Your RSVP',
          style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.md),
        // Primary status chips: Going / Maybe / Can't
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _RsvpChip(
              label: 'Going',
              active: _isGoing,
              enabled: enabled,
              onTap: () {
                // Preserve current guest count when re-tapping "Going".
                widget.onRsvp(_rsvpForGuestCount(_currentGuestCount));
              },
            ),
            _RsvpChip(
              label: 'Maybe',
              active: current == Rsvp.maybe,
              enabled: enabled,
              onTap: () => widget.onRsvp(Rsvp.maybe),
            ),
            _RsvpChip(
              label: "Can't come",
              active: current == Rsvp.cant,
              enabled: enabled,
              onTap: () => widget.onRsvp(Rsvp.cant),
            ),
          ],
        ),
        // Guest-count stepper — only visible when "Going" is selected.
        if (_isGoing && enabled) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(
                Icons.group_outlined,
                size: 16,
                color: AppColors.mutedForeground,
              ),
              const SizedBox(width: AppSpacing.sm),
              // Flexible, not a bare Text: at a 320px width the icon, this
              // label and the fixed-width stepper together are tight enough
              // that the label needs to be the one that gives way, rather
              // than overflow the row.
              Flexible(
                child: Text(
                  'Bringing guests',
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              const Spacer(),
              _GuestCountStepper(
                value: _currentGuestCount,
                max: 4,
                onChanged: (n) {
                  widget.onRsvp(_rsvpForGuestCount(n));
                },
              ),
            ],
          ),
          if (_currentGuestCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'You + $_currentGuestCount guest${_currentGuestCount > 1 ? 's' : ''} = ${_currentGuestCount + 1} total seats',
                style: AppTypography.bodyXs.copyWith(color: AppColors.success),
              ),
            ),
        ],
        if (widget.cutoffPassed)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'RSVPs are now closed.',
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        if (lastError != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              lastError,
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.destructiveText,
              ),
            ),
          ),
      ],
    );
  }
}

/// A compact +/− stepper for the guest count (0–max).
class _GuestCountStepper extends StatelessWidget {
  const _GuestCountStepper({
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int max;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: Icons.remove,
          tooltip: 'One fewer guest',
          enabled: value > 0,
          onTap: () => onChanged(value - 1),
        ),
        SizedBox(
          width: 44,
          child: Center(
            child: Text(
              '$value',
              style: AppTypography.monoSm.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
          ),
        ),
        _StepButton(
          icon: Icons.add,
          tooltip: 'One more guest',
          enabled: value < max,
          onTap: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  /// What this button does. Both halves of the stepper are icon-only, so
  /// without it a screen reader announces the guest count as two unnamed
  /// buttons either side of a number.
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            // kMinTapTarget, not 44: 44 is Apple's floor, and this is
            // operated one-handed at a table. Take the larger of the two.
            width: kMinTapTarget,
            height: kMinTapTarget,
            decoration: BoxDecoration(
              color: enabled ? AppColors.primary : AppColors.muted,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              icon,
              size: 16,
              color: enabled
                  ? AppColors.primaryForeground
                  : AppColors.mutedForeground,
            ),
          ),
        ),
      ),
    );
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
                    'Admin: $hostName',
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
