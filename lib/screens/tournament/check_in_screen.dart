import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/game.dart';
import '../../models/live_game.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_alert_banner.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';

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

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final game = app.currentGame;

    if (game == null) {
      return Center(
        child: Text('No game selected.', style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
      );
    }

    final players = game.players;
    final checkedIn = players.where((p) => p.checkedIn && p.confirmed).toList();
    final notCheckedIn = players.where((p) => !p.checkedIn && !p.isGuest).toList();
    final pendingGuests = players.where((p) => p.isGuest && !p.confirmed && p.name.isNotEmpty).toList();
    final confirmedGuests = players.where((p) => p.isGuest && p.confirmed).toList();
    final canStart = checkedIn.length >= 2;
    final seatedYet = checkedIn.any((p) => p.table > 0 && p.seat > 0);
    final seatingConfirmed = game.seatingConfirmed;

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
                  Text('Check-in', style: AppTypography.display(size: AppFontSizes.xxxl, weight: FontWeight.w700)),
                  Text(game.settings.name, style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Summary
          Row(
            children: [
              Expanded(
                child: _SummaryCard(label: 'Checked in', value: '${checkedIn.length}', color: AppColors.success),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SummaryCard(label: 'Pending guests', value: '${pendingGuests.length}', color: AppColors.warning),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SummaryCard(label: 'Not arrived', value: '${notCheckedIn.length}', color: AppColors.mutedForeground),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (pendingGuests.isNotEmpty) ...[
            AppAlertBanner(
              type: AppAlertType.warning,
              message: '${pendingGuests.length} guest${pendingGuests.length > 1 ? 's' : ''} waiting for confirmation',
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          // Pending guest requests
          if (pendingGuests.isNotEmpty) ...[
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pending guest requests',
                    style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600, color: AppColors.warning),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final g in pendingGuests) ...[
                    _PendingGuestRow(
                      guest: g,
                      inviter: players.where((p) => p.id == g.inviterId).firstOrNull,
                      onConfirm: () => app.confirmGuest(g.id),
                      onReject: () => app.rejectGuest(g.id),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          // Players
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Players', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.xs),
                for (final p in players.where((p) => !p.isGuest))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      children: [
                        AppAvatar(name: p.name, size: AppAvatarSize.sm),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, style: AppTypography.bodySm),
                              if (p.rsvp != null)
                                Text(
                                  '${p.rsvp!.label} RSVP',
                                  style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                                ),
                            ],
                          ),
                        ),
                        if (p.checkedIn)
                          const AppBadge(label: 'Checked in', variant: AppBadgeVariant.green)
                        else
                          AppButton(
                            size: AppButtonSize.sm,
                            variant: AppButtonVariant.secondary,
                            onPressed: () => app.checkInPlayer(p.id),
                            child: const Text('Check in'),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Confirmed guests
          if (confirmedGuests.isNotEmpty) ...[
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Confirmed guests', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.xs),
                  for (final g in confirmedGuests)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
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
                                  style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                                ),
                              ],
                            ),
                          ),
                          const AppBadge(label: 'Confirmed', variant: AppBadgeVariant.green),
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
                Text('Seating', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
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
                          style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
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
                                  style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: AppSpacing.sm,
                                    crossAxisSpacing: AppSpacing.sm,
                                    childAspectRatio: 1.6,
                                  ),
                                  itemCount: byTable[table]!.length,
                                  itemBuilder: (context, i) {
                                    final p = byTable[table]![i];
                                    final isDealer = p.id == game.dealerPlayerId;
                                    return Container(
                                      padding: const EdgeInsets.all(AppSpacing.sm),
                                      decoration: BoxDecoration(
                                        color: isDealer ? AppColors.primarySoft : AppColors.secondary,
                                        borderRadius: BorderRadius.circular(AppRadius.md),
                                        border: Border.all(
                                          color: isDealer ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            isDealer ? 'Dealer · Seat ${p.seat}' : 'Seat ${p.seat}',
                                            style: AppTypography.bodyXs.copyWith(
                                              color: isDealer ? AppColors.primary : AppColors.mutedForeground,
                                              fontWeight: isDealer ? FontWeight.w700 : null,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            p.name,
                                            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w500),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (p.isGuest)
                                            Text('Guest', style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
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
          // Start game
          if (!seatedYet)
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Generate the seating plan above, then confirm it before starting the game.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
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
                    style: AppTypography.bodySm.copyWith(color: AppColors.warning),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    variant: AppButtonVariant.primary,
                    fullWidth: true,
                    onPressed: app.confirmSeating,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: AppColors.icon),
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
                  const Icon(Icons.check_circle, size: AppFontSizes.xl, color: AppColors.success),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Seating confirmed. You can start the game.',
                      style: AppTypography.bodySm.copyWith(color: AppColors.success),
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
                  child: const Row(
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
                          app.updateGameStatus(LiveGameStatus.running);
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
                          const Icon(Icons.arrow_forward, size: 14, color: AppColors.icon),
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Text(value, style: AppTypography.monoXl.copyWith(fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          AppAvatar(name: guest.name.isEmpty ? '?' : guest.name, size: AppAvatarSize.sm),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(guest.name, style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w500)),
                Text(
                  'Invited by ${inviter?.name ?? '?'}',
                  style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppButton(
            size: AppButtonSize.sm,
            onPressed: onConfirm,
            child: const Text('Confirm'),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppButton(
            size: AppButtonSize.sm,
            variant: AppButtonVariant.danger,
            onPressed: onReject,
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

class _SeatingOption extends StatelessWidget {
  const _SeatingOption({required this.label, required this.active, required this.onTap});

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
          border: Border.all(color: active ? AppColors.primary : AppColors.border),
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
