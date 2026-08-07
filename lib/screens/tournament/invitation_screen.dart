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
import '../../providers/app_provider.dart';
import '../../utils/formatters.dart';
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
          // My RSVP
          if (user != null) ...[
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your RSVP', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final opt in const [
                        Rsvp.going,
                        Rsvp.maybe,
                        Rsvp.cant,
                        Rsvp.goingPlus1,
                        Rsvp.goingPlus2,
                        Rsvp.goingPlus3,
                        Rsvp.goingPlus4,
                      ])
                        _RsvpOption(
                          label: opt.label,
                          active: myPlayer?.rsvp == opt,
                          enabled: !game.settings.rsvpCutoffPassed,
                          onTap: () => app.setRSVP(opt),
                        ),
                    ],
                  ),
                  if (game.settings.rsvpCutoffPassed) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        const Icon(Icons.lock_outline, size: AppFontSizes.sm, color: AppColors.warning),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'RSVP changes closed — one hour before the game. Contact the organiser for changes.',
                            style: AppTypography.bodyXs.copyWith(color: AppColors.warning),
                          ),
                        ),
                      ],
                    ),
                  ] else if (myPlayer?.rsvp != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'RSVP deadline: ${_deadlineLabel(settings)}',
                      style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
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
          if (user?.isAdmin == true) ...[
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              borderColor: AppColors.primary.withValues(alpha: 0.2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Admin actions', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600, color: AppColors.primary)),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      AppButton(
                        size: AppButtonSize.sm,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => context.go(RoutePaths.checkIn),
                        child: const Text('Open check-in'),
                      ),
                      AppButton(
                        size: AppButtonSize.sm,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => _openEditModal(context, app, game),
                        child: const Text('Edit details'),
                      ),
                      AppButton(
                        size: AppButtonSize.sm,
                        onPressed: () => context.go(RoutePaths.adminDashboard),
                        child: const Text('Dashboard'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ],
      ),
    );
  }

  String _deadlineLabel(GameSettings settings) {
    final parts = settings.date.split('-');
    if (parts.length != 3) return '1 hour before game';
    final dt = DateTime.tryParse('${settings.date}T${settings.time}');
    if (dt == null) return '1 hour before game';
    final deadline = dt.subtract(const Duration(hours: 1));
    return Formatters.shortDateTime(deadline);
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
      onSave: (next) {
        app.updateEventSettings(next);
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
  final ValueChanged<GameSettings> onSave;

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
    widget.onSave(s.copyWith(
      name: _name.text.trim().isEmpty ? s.name : _name.text.trim(),
      date: _date.text.trim().isEmpty ? s.date : _date.text.trim(),
      time: _time.text.trim().isEmpty ? s.time : _time.text.trim(),
      location: _location.text.trim(),
      buyIn: num.tryParse(_buyIn.text)?.toInt() ?? s.buyIn,
      players: num.tryParse(_players.text)?.toInt() ?? s.players,
      locationPrivate: _locationPrivate,
    ));
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
