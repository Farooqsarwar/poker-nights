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
import '../../models/live_game.dart';
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

/// Invitation / RSVP page mirroring the web `InvitationPage`.
class InvitationScreen extends StatefulWidget {
  const InvitationScreen({super.key});

  @override
  State<InvitationScreen> createState() => _InvitationScreenState();
}

class _InvitationScreenState extends State<InvitationScreen> {
  bool _copied = false;

  Future<void> _copyLink(LiveGame game) async {
    await Clipboard.setData(ClipboardData(text: 'https://pokernight.app/game/${game.publicCode}'));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final game = app.currentGame;
    final user = app.user;

    if (game == null) {
      return Center(
        child: Text('No game selected.', style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
      );
    }

    final settings = game.settings;
    final myPlayer = game.players.where((p) => p.id == user?.id).firstOrNull;
    final going = game.players.where((p) => p.rsvp != null && p.rsvp!.isGoing).toList();
    final total = game.players
        .where((p) => p.rsvp != null && p.rsvp!.isGoing)
        .fold<int>(0, (s, p) => s + 1 + p.rsvp!.guestCount);
    // Categorized attendance (spec §4.4) — people and seats are both shown.
    final members = game.players.where((p) => !p.isGuest).toList();
    final confirmedMembers =
        members.where((p) => p.rsvp != null && p.rsvp!.isGoing).toList();
    final confirmedMemberCount = confirmedMembers.length;
    final memberSeats =
        confirmedMembers.fold<int>(0, (s, p) => s + 1 + p.rsvp!.guestCount);
    final claimedGuestSlots = game.guestSlots.where((s) => !s.available).length;
    final guestSlotsTotal = game.guestSlots.length;
    final maybeCount = members.where((p) => p.rsvp == Rsvp.maybe).length;
    final cantCount = members.where((p) => p.rsvp == Rsvp.cant).length;
    final noResponseCount = members.where((p) => p.rsvp == null).length;
    // Private addresses are hidden until the viewer is confirmed (11-015).
    final showAddress = !settings.locationPrivate ||
        (user?.isAdmin ?? false) ||
        (myPlayer?.confirmed ?? false);

    return AppPage(
      maxWidth: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    Text(settings.name, style: AppTypography.display(size: AppFontSizes.xxxl, weight: FontWeight.w700)),
                    Text(
                      showAddress
                          ? '${settings.date} at ${settings.time} · ${settings.location}'
                          : '${settings.date} at ${settings.time} · Address shared at check-in',
                      style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
                    ),
                  ],
                ),
              ),
              if (user?.isAdmin == true) ...[
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  onPressed: () => _openEditModal(context, app, game),
                  icon: const Icon(Icons.edit_outlined, color: AppColors.mutedForeground),
                  tooltip: 'Edit details',
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Game details
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Wrap(
              runSpacing: AppSpacing.md,
              spacing: AppSpacing.lg,
              children: [
                _Detail(label: 'Buy-in', value: '${settings.buyIn}', valueColor: AppColors.primary, mono: true),
                if (settings.koEnabled)
                  _Detail(label: 'KO bounty', value: '${settings.buyIn} + ${settings.koAmount}', valueColor: AppColors.primary, mono: true),
                _Detail(label: 'Duration', value: '${settings.durationHours == settings.durationHours.roundToDouble() ? settings.durationHours.round() : settings.durationHours}h', mono: true),
                _Detail(label: 'Confirmed', value: '$total players', valueColor: AppColors.success, mono: true),
                _Detail(
                  label: 'Rebuys',
                  value: settings.rebuys
                      ? 'Until L${settings.rebuysCloseLevel} @ ${settings.effectiveRebuyCost}'
                      : 'None',
                ),
                _Detail(
                  label: 'Add-on',
                  value: settings.addOn ? 'Enabled @ ${settings.effectiveAddOnCost}' : 'None',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _ContextualMainButton(game: game, user: user, myPlayer: myPlayer),

          const SizedBox(height: AppSpacing.lg),
          // Attendance summary (spec §4.4) — people and seats
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Attendance', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.sm),
                _AttendanceRow(label: 'Confirmed members', value: '$confirmedMemberCount people · $memberSeats seats', highlight: true),
                _AttendanceRow(
                  label: 'Confirmed guest slots',
                  value: guestSlotsTotal > 0 ? '$claimedGuestSlots of $guestSlotsTotal claimed' : '0',
                  highlight: true,
                ),
                _AttendanceRow(label: 'Maybe', value: '$maybeCount'),
                _AttendanceRow(label: 'Can\u2019t come', value: '$cantCount'),
                _AttendanceRow(label: 'No response', value: '$noResponseCount'),
                const Divider(color: AppColors.border, height: 24),
                _AttendanceRow(
                  label: 'Expected attendance',
                  value: '$memberSeats people',
                  valueColor: AppColors.success,
                  bold: true,
                ),
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
                  Text('Event-day checklist', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600, color: AppColors.primary)),
                  const SizedBox(height: 2),
                  Text(
                    'Walk through preparation in order — no need to remember the sequence.',
                    style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _ChecklistRow(
                    label: 'Open check-in',
                    done: game.status == LiveGameStatus.checkin ||
                        game.players.any((p) => p.checkedIn),
                    actionLabel: 'Open',
                    onAction: () => context.go(RoutePaths.checkIn),
                  ),
                  _ChecklistRow(
                    label: 'Configure chip set',
                    done: app.savedChipSets.isNotEmpty,
                    actionLabel: 'Configure',
                    onAction: () => context.go(RoutePaths.chipSets),
                  ),
                  _ChecklistRow(
                    label: 'Generate seating plan',
                    done: game.seatingConfirmed,
                    actionLabel: 'Seating',
                    onAction: () => context.go(RoutePaths.checkIn),
                  ),
                  _ChecklistRow(
                    label: 'Start the tournament',
                    done: game.status == LiveGameStatus.running ||
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
                Text('Share with guests', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
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
                          ? const AppIconLabel(label: 'Link copied', icon: Icons.check_circle, color: AppColors.success)
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
                  style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
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
                Text('Responses', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.sm),
                for (final p in game.players.where((p) => !p.isGuest))
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
                if (going.isNotEmpty) ...[
                  const Divider(color: AppColors.border),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Text('Total confirmed (incl. guests)', style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
                      const Spacer(),
                      Text(
                        '$total',
                        style: AppTypography.monoXs.copyWith(color: AppColors.success, fontWeight: FontWeight.w600),
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
                  Text('Guest seats', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.sm),
                  for (final slot in game.guestSlots) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.event_seat_outlined, size: 16, color: AppColors.icon),
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
                    const SizedBox(height: 2),
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
  const _Detail({required this.label, required this.value, this.valueColor, this.mono = false});

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
          Text(label, style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
          const SizedBox(height: 2),
          Text(
            value,
            style: mono
                ? AppTypography.monoSm.copyWith(fontWeight: FontWeight.w600, color: valueColor ?? AppColors.foreground)
                : AppTypography.bodySm.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _RsvpOption extends StatelessWidget {
  const _RsvpOption({required this.label, required this.active, this.enabled = true, required this.onTap});

  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: active ? AppColors.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: active ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: AppTypography.bodySm.copyWith(
            color: !enabled
                ? AppColors.mutedForeground
                : active
                    ? AppColors.primary
                    : AppColors.mutedForeground,
            fontWeight: FontWeight.w500,
          ),
        ),
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

class _GuestSlotBadge extends StatelessWidget {
  const _GuestSlotBadge({required this.status});

  final GuestSlotStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, variant) = switch (status) {
      GuestSlotStatus.unclaimed => ('Free', AppBadgeVariant.muted),
      GuestSlotStatus.reserved => ('Pending', AppBadgeVariant.accent),
      GuestSlotStatus.checkedIn => ('Checked in', AppBadgeVariant.green),
      GuestSlotStatus.cancelled => ('Cancelled', AppBadgeVariant.red),
    };
    return AppBadge(label: label, variant: variant, border: true);
  }
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
  late final TextEditingController _players;
  late bool _locationPrivate;

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _name = TextEditingController(text: s.name);
    _date = TextEditingController(text: s.date);
    _time = TextEditingController(text: s.time);
    _location = TextEditingController(text: s.location);
    _buyIn = TextEditingController(text: '${s.buyIn}');
    _players = TextEditingController(text: '${s.players}');
    _locationPrivate = s.locationPrivate;
  }

  @override
  void dispose() {
    for (final c in [_name, _date, _time, _location, _buyIn, _players]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final s = widget.settings;
    final newDate = _date.text.trim().isEmpty ? s.date : _date.text.trim();
    final newTime = _time.text.trim().isEmpty ? s.time : _time.text.trim();
    final newS = s.copyWith(
      name: _name.text.trim().isEmpty ? s.name : _name.text.trim(),
      date: newDate,
      time: newTime,
      location: _location.text.trim(),
      buyIn: num.tryParse(_buyIn.text)?.toInt() ?? s.buyIn,
      players: num.tryParse(_players.text)?.toInt() ?? s.players,
      locationPrivate: _locationPrivate,
    );

    if (s.date != newDate || s.time != newTime) {
      showAppModal(
        context: context,
        title: 'Date or Time Changed',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('You have changed the scheduled date or time. Would you like to clear existing RSVPs so players must confirm they can still make it?'),
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
        AppTextField(controller: _location, label: 'Location'),
        const SizedBox(height: AppSpacing.sm),
        _ToggleRow(
          title: 'Keep address private',
          subtitle: 'Hidden on public views until check-in',
          value: _locationPrivate,
          onChanged: (v) => setState(() => _locationPrivate = v),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _buyIn,
                label: 'Buy-in',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppTextField(
                controller: _players,
                label: 'Expected players',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Changing buy-in or player count regenerates the structure. '
          'All edits are recorded in the audit log and shared with members.',
          style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
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
                Text(title, style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
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
        side: const BorderSide(color: AppColors.border),
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
                data: 'https://pokernight.app/game/${game.publicCode}',
                version: QrVersions.auto,
                size: 200,
                gapless: false,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'https://pokernight.app/game/${game.publicCode}',
              textAlign: TextAlign.center,
              style: AppTypography.monoSm.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Guests scan this to open the join page — no account needed.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
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
    this.valueColor,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool highlight;
  final Color? valueColor;
  final bool bold;

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
                color: highlight ? AppColors.foreground : AppColors.mutedForeground,
                fontWeight: highlight ? FontWeight.w500 : null,
              ),
            ),
          ),
          Text(
            value,
            style: AppTypography.monoXs.copyWith(
              color: valueColor ?? (highlight ? AppColors.foreground : AppColors.mutedForeground),
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
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
  const _ContextualMainButton({required this.game, required this.user, required this.myPlayer});

  final LiveGame game;
  final AppUser? user;
  final Player? myPlayer;

  void _showRsvpModal(BuildContext context, AppProvider app) {
    // If cutoff passed, we don't allow RSVP changes, only check-in.
    // We check the status to ensure it's still in the invitation phase.
    final cutoffPassed = game.settings.rsvpCutoffPassed;
    if (cutoffPassed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('RSVP window has closed. Please check in at the venue.'),
          backgroundColor: AppColors.mutedForeground,
        ),
      );
      return;
    }

    showAppModal(
      context: context,
      title: 'Update your RSVP',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final opt in const [Rsvp.going, Rsvp.maybe, Rsvp.cant, Rsvp.goingPlus1, Rsvp.goingPlus2, Rsvp.goingPlus3, Rsvp.goingPlus4])
                _RsvpOption(
                  label: opt.label,
                  active: myPlayer?.rsvp == opt,
                  enabled: true,
                  onTap: () {
                    app.setRSVP(opt);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

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
            child: const Text('Edit Event'),
          );
        case LiveGameStatus.published:
          return AppButton(
            fullWidth: true,
            size: AppButtonSize.xl,
            onPressed: () => context.go(RoutePaths.checkIn),
            child: const Text('Review RSVPs'),
          );
        case LiveGameStatus.checkin:
          final checkedInCount = game.players.where((p) => p.checkedIn && p.confirmed).length;
          final seatingConfirmed = game.seatingConfirmed;
          if (checkedInCount >= 2 && seatingConfirmed) {
            return AppButton(
              fullWidth: true,
              size: AppButtonSize.xl,
              onPressed: () {
                app.updateEventSettings(game.settings.copyWith(players: checkedInCount));
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
      
      final isRunning = game.status == LiveGameStatus.running || game.status == LiveGameStatus.paused || game.status == LiveGameStatus.finaltable || game.status == LiveGameStatus.rebuypause;
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
          return AppButton(
            fullWidth: true,
            size: AppButtonSize.xl,
            variant: AppButtonVariant.secondary,
            onPressed: () => showAppModal(
              context: context,
              title: 'Your Seat Assignment',
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Center(
                  child: Text(
                    'Table ${p.table} · Seat ${p.seat}',
                    style: AppTypography.display(size: AppFontSizes.xxxl, weight: FontWeight.bold),
                  ),
                ),
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
        } else if (game.status == LiveGameStatus.checkin) {
          return AppButton(
            fullWidth: true,
            size: AppButtonSize.xl,
            onPressed: () => app.requestCheckIn(p.id),
            child: const Text('Check In'),
          );
        } else {
          return AppButton(
            fullWidth: true,
            size: AppButtonSize.xl,
            onPressed: () => _showRsvpModal(context, app),
            child: Text(p.rsvp != null ? 'Update RSVP' : 'Respond to Invitation'),
          );
        }
      }
    }
    return const SizedBox.shrink();
  }
}
