import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/game.dart';
import '../../providers/app_provider.dart';
import '../../utils/voice_service.dart';
import '../../widgets/app_alert_banner.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon_label.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/event_day_checklist.dart';

enum SeatingMode { random, manual, keepGuests, separateGuests }

extension SeatingModeLabel on SeatingMode {
  String get label => switch (this) {
    SeatingMode.random => 'Fully random',
    SeatingMode.manual => 'Manual',
    SeatingMode.keepGuests => 'Guests with inviter',
    SeatingMode.separateGuests => 'Guests separate',
  };

  /// Maps the screen enum to the provider's seating enum.
  TableSeatingMode get tableMode => switch (this) {
    SeatingMode.random => TableSeatingMode.random,
    SeatingMode.manual => TableSeatingMode.manual,
    SeatingMode.keepGuests => TableSeatingMode.keepGuests,
    SeatingMode.separateGuests => TableSeatingMode.separateGuests,
  };
}

/// Check-in page mirroring the web `CheckInPage`.
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  SeatingMode _seatingMode = SeatingMode.random;
  bool _seatingModeInitialized = false;

  /// The checked-in count the split prompt was last shown/dismissed for, so
  /// it doesn't re-open every rebuild once the admin has responded to it at
  /// this count.
  int? _splitPromptRespondedAtCount;
  bool _splitPromptShowing = false;

  /// Once seating is generated the count naturally sits at/above the
  /// threshold on every rebuild; only prompt before that first generation.
  void _maybeShowSplitPrompt(
    BuildContext context,
    AppProvider app,
    int checkedInCount,
    int maxPerTable,
    bool seatedYet,
  ) {
    if (seatedYet ||
        checkedInCount < maxPerTable ||
        _splitPromptShowing ||
        _splitPromptRespondedAtCount == checkedInCount) {
      return;
    }
    _splitPromptShowing = true;
    showAppModal(
      context: context,
      title: 'Split into multiple tables?',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$checkedInCount players have checked in — that\'s enough to '
            'split across multiple tables (max $maxPerTable per table). '
            'Generate seating now?',
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
                  onPressed: () {
                    _splitPromptRespondedAtCount = checkedInCount;
                    Navigator.of(context).pop();
                  },
                  child: const Text('Not yet'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  onPressed: () {
                    _splitPromptRespondedAtCount = checkedInCount;
                    app.generateSeating(_seatingMode.tableMode);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Generate seating'),
                ),
              ),
            ],
          ),
        ],
      ),
    ).then((_) {
      _splitPromptShowing = false;
    });
  }

  void _showWalkInModal(BuildContext context, AppProvider app) {
    final controller = TextEditingController();
    showAppModal(
      context: context,
      title: 'Walk-in guest',
      child: StatefulBuilder(
        builder: (context, setModalState) {
          final name = controller.text.trim();
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Register someone who showed up without an RSVP. They are checked in immediately and seated with the next seating generation.',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: controller,
                label: 'Name',
                autofocus: true,
                onChanged: (_) => setModalState(() {}),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      onPressed: name.isEmpty
                          ? null
                          : () {
                              app.addWalkInPlayer(name);
                              Navigator.of(context).pop();
                            },
                      child: const Text('Check in'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final game = app.currentGame;
    final isAdmin = app.isAdmin;

    // Seating setup is admin-only. Players see their seat from the invitation
    // screen, never this setup UI (client feedback 07-018).
    if (!isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(RoutePaths.invitation);
      });
      return const SizedBox.shrink();
    }

    if (game == null) {
      // No game in provider — redirect back to a safe screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(RoutePaths.invitation);
      });
      return const SizedBox.shrink();
    }

    if (!_seatingModeInitialized) {
      _seatingModeInitialized = true;
      _seatingMode = app.effectiveTableSettings.randomizeByDefault
          ? SeatingMode.random
          : SeatingMode.manual;
    }

    final players = game.players;
    final checkedIn = players.where((p) => p.checkedIn && p.confirmed).toList();
    final notCheckedIn = players
        .where((p) => !p.checkedIn && !p.isGuest)
        .toList();
    final pendingRequests = players
        .where(
          (p) =>
              !p.confirmed && (p.checkedIn || (p.isGuest && p.name.isNotEmpty)),
        )
        .toList();
    final confirmedGuests = players
        .where((p) => p.isGuest && p.confirmed)
        .toList();
    final canStart = checkedIn.length >= 2;
    final seatedYet = checkedIn.any((p) => p.table > 0 && p.seat > 0);
    final seatingConfirmed = game.seatingConfirmed;
    // Event-day preparation checklist (user-flow spec §4.6): admin-only and
    // only in the pre-live window (published / check-in / ready).
    final showChecklist = EventDayChecklist.appliesTo(game);

    // Table-split prompt (configurable threshold, spec §5e): once check-in
    // reaches the group/tournament's configured capacity, offer to generate
    // seating across multiple tables instead of silently waiting for a
    // manual click.
    final maxPerTable = app.effectiveTableSettings.maxPerTable;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _maybeShowSplitPrompt(
          context,
          app,
          checkedIn.length,
          maxPerTable,
          seatedYet,
        );
      }
    });

    return AppPage(
      maxWidth: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppBackButton(onTap: () => context.go(RoutePaths.invitation)),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Check-in',
                    style: AppTypography.display(
                      size: AppFontSizes.xxxl,
                      weight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    game.settings.name,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Event-day preparation (user-flow spec §4.6) — always the first
          // card so the admin never has to remember the sequence. We are on
          // the check-in screen itself, so step 2 has no open action.
          if (showChecklist) ...[
            EventDayChecklist(
              game: game,
              onOpenCheckIn: null,
              onOpenTvMode: () => context.go(RoutePaths.tvMode),
              onTestVoice: () {
                VoiceService.instance.speak('Voice test.');
              },
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          // Summary
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _InlineStat(
                  label: 'Checked in',
                  value: '${checkedIn.length}/${players.length}',
                  color: AppColors.success,
                ),
                Container(width: 1, height: 24, color: AppColors.border),
                _InlineStat(
                  label: 'Pending',
                  value: '${pendingRequests.length}',
                  color: AppColors.warning,
                ),
                Container(width: 1, height: 24, color: AppColors.border),
                _InlineStat(
                  label: 'Not arrived',
                  value: '${notCheckedIn.length}',
                  color: AppColors.mutedForeground,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (pendingRequests.isNotEmpty) ...[
            AppAlertBanner(
              type: AppAlertType.warning,
              message:
                  '${pendingRequests.length} player${pendingRequests.length > 1 ? 's' : ''} waiting for confirmation',
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          // Pending requests
          if (pendingRequests.isNotEmpty) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                  child: Text(
                    'PENDING CHECK-IN REQUESTS',
                    style: AppTypography.bodyXs.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: AppColors.warning,
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Container(
                    color: AppColors.card,
                    child: Column(
                      children: [
                        for (final g in pendingRequests)
                          _PendingGuestRow(
                            guest: g,
                            inviter: g.isGuest
                                ? players
                                      .where((p) => p.id == g.inviterId)
                                      .firstOrNull
                                : null,
                            onConfirm: () => g.isGuest
                                ? app.confirmGuest(g.id)
                                : app.checkInPlayer(g.id),
                            onReject: () => g.isGuest
                                ? app.rejectGuest(g.id)
                                : app.cancelCheckIn(g.id),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          // Players
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                child: Text(
                  'PLAYERS',
                  style: AppTypography.bodyXs.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Container(
                  color: AppColors.card,
                  child: Column(
                    children: [
                      for (final p in players.where((p) => !p.isGuest))
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                            horizontal: AppSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppColors.border)),
                          ),
                          child: Row(
                            children: [
                              AppAvatar(name: p.name, size: AppAvatarSize.sm),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.name, style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
                                    if (p.rsvp != null)
                                      Text(
                                        '${p.rsvp!.label} RSVP',
                                        style: AppTypography.bodyXs.copyWith(
                                          color: AppColors.mutedForeground,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (p.checkedIn)
                                const AppBadge(
                                  label: 'Checked in',
                                  variant: AppBadgeVariant.green,
                                )
                              else
                                AppButton(
                                  size: AppButtonSize.sm,
                                  variant: AppButtonVariant.secondary,
                                  onPressed: game.checkInClosed
                                      ? null
                                      : () => app.checkInPlayer(p.id),
                                  child: Text(
                                    game.checkInClosed
                                        ? 'Check-in closed'
                                        : 'Check in',
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Confirmed guests
          if (confirmedGuests.isNotEmpty) ...[
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Confirmed guests',
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final g in confirmedGuests)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          AppAvatar(name: g.name, size: AppAvatarSize.sm),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(g.name, style: AppTypography.bodySm),
                                Text(
                                  'Guest of ${players.where((p) => p.id == g.inviterId).firstOrNull?.name ?? '?'}',
                                  style: AppTypography.bodyXs.copyWith(
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const AppBadge(
                            label: 'Confirmed',
                            variant: AppBadgeVariant.green,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          // Seating
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seating',
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 2.4,
                  children: [
                    for (final mode in SeatingMode.values)
                      _SeatingOption(
                        label: mode.label,
                        active: _seatingMode == mode,
                        onTap: () {
                          setState(() => _seatingMode = mode);
                          app.generateSeating(mode.tableMode);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Seating preview — grouped by the table each player is assigned to.
          if (checkedIn.isNotEmpty)
            Builder(
              builder: (context) {
                final byTable = <int, List<Player>>{};
                for (final p in checkedIn) {
                  byTable.putIfAbsent(p.table, () => []).add(p);
                }
                for (final list in byTable.values) {
                  list.sort((a, b) => a.seat.compareTo(b.seat));
                }
                final seatedYet = byTable.keys.any((t) => t > 0);
                final tables = byTable.keys.toList()..sort();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!seatedYet)
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          'Pick a seating mode above to generate tables and seats.',
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      )
                    else
                      for (final table in tables)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: AppCard(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Table $table — ${byTable[table]!.length} seats',
                                  style: AppTypography.bodySm.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        mainAxisSpacing: AppSpacing.sm,
                                        crossAxisSpacing: AppSpacing.sm,
                                        childAspectRatio: 1.6,
                                      ),
                                  itemCount: byTable[table]!.length,
                                  itemBuilder: (context, i) {
                                    final p = byTable[table]![i];
                                    final isDealer =
                                        p.id == game.dealerPlayerId;
                                    return Container(
                                      padding: const EdgeInsets.all(
                                        AppSpacing.sm,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDealer
                                            ? AppColors.primarySoft
                                            : AppColors.secondary,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.md,
                                        ),
                                        border: Border.all(
                                          color: isDealer
                                              ? AppColors.primary.withValues(
                                                  alpha: 0.5,
                                                )
                                              : AppColors.border,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            isDealer
                                                ? 'Dealer · Seat ${p.seat}'
                                                : 'Seat ${p.seat}',
                                            style: AppTypography.bodyXs
                                                .copyWith(
                                                  color: isDealer
                                                      ? AppColors.primary
                                                      : AppColors
                                                            .mutedForeground,
                                                  fontWeight: isDealer
                                                      ? FontWeight.w700
                                                      : null,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            p.name,
                                            style: AppTypography.bodySm
                                                .copyWith(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (p.isGuest)
                                            Text(
                                              'Guest',
                                              style: AppTypography.bodyXs
                                                  .copyWith(
                                                    color: AppColors
                                                        .mutedForeground,
                                                  ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                );
              },
            ),
          const SizedBox(height: AppSpacing.lg),
          // Check-in controls (admin)
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        variant: AppButtonVariant.secondary,
                        onPressed: game.checkInClosed
                            ? app.reopenCheckIn
                            : app.closeCheckIn,
                        child: Text(
                          game.checkInClosed
                              ? 'Reopen check-in'
                              : 'Close check-in',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton(
                        variant: AppButtonVariant.secondary,
                        onPressed: game.rebuysClosed
                            ? null
                            : () => _showWalkInModal(context, app),
                        child: const Text('Walk-in'),
                      ),
                    ),
                  ],
                ),
                if (game.rebuysClosed) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppAlertBanner(
                    type: AppAlertType.warning,
                    message: 'Late registration is permanently closed. No new players can be added.',
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  variant: AppButtonVariant.ghost,
                  onPressed: () => context.go(RoutePaths.tvMode),
                  child: const AppIconLabel(
                    label: 'Show assignment on TV',
                    icon: Icons.tv_outlined,
                  ),
                ),
                if (game.checkInClosed) ...[
                  const SizedBox(height: AppSpacing.md),
                  const AppAlertBanner(
                    type: AppAlertType.warning,
                    message:
                        'Check-in is closed. Reopen to accept more players or start the tournament below.',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Start game
          if (!seatedYet)
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Generate the seating plan above, then confirm it before starting the game.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            )
          else if (!seatingConfirmed)
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              borderColor: AppColors.warning.withValues(alpha: 0.4),
              child: Column(
                children: [
                  Text(
                    'Seating has been generated but not yet confirmed.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    variant: AppButtonVariant.primary,
                    fullWidth: true,
                    onPressed: app.confirmSeating,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: AppColors.icon,
                        ),
                        SizedBox(width: 6),
                        Text('Confirm physical seating'),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              borderColor: AppColors.successSoftBorder,
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: AppFontSizes.xl,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Seating confirmed. You can start the game.',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  variant: AppButtonVariant.secondary,
                  onPressed: () => context.go(RoutePaths.invitation),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back, size: 14, color: AppColors.icon),
                      SizedBox(width: 6),
                      Text('Back'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  onPressed: canStart && seatingConfirmed
                      ? () {
                          app.updateEventSettings(
                            game.settings.copyWith(players: checkedIn.length),
                          );
                          app.startTimer();
                          context.go(RoutePaths.adminDashboard);
                        }
                      : null,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          !canStart
                              ? 'Need at least 2 checked in'
                              : !seatingConfirmed
                              ? 'Confirm seating first'
                              : 'Start with ${checkedIn.length} players',
                        ),
                        if (canStart && seatingConfirmed) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward,
                            size: 14,
                            color: AppColors.icon,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  const _InlineStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.monoXl.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: AppTypography.bodyXs.copyWith(
            color: AppColors.mutedForeground,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PendingGuestRow extends StatelessWidget {
  const _PendingGuestRow({
    required this.guest,
    required this.inviter,
    required this.onConfirm,
    required this.onReject,
  });

  final Player guest;
  final Player? inviter;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          AppAvatar(
            name: guest.name.isEmpty ? '?' : guest.name,
            size: AppAvatarSize.sm,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guest.name,
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Invited by ${inviter?.name ?? '?'}',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            icon: Icon(Icons.check_circle_outline, color: AppColors.success),
            onPressed: onConfirm,
            tooltip: 'Confirm',
          ),
          IconButton(
            icon: Icon(Icons.cancel_outlined, color: AppColors.destructive),
            onPressed: onReject,
            tooltip: 'Reject',
          ),
        ],
      ),
    );
  }
}

class _SeatingOption extends StatelessWidget {
  const _SeatingOption({
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
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.bodySm.copyWith(
            color: active ? AppColors.primary : AppColors.mutedForeground,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
