import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/game.dart';
import '../../models/live_game.dart';
import '../../models/tournament.dart';
import '../../providers/app_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_alert_banner.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_page.dart';
import '../../widgets/medal_icon.dart';

class _PodiumResult {
  const _PodiumResult({
    required this.player,
    required this.pos,
    required this.prize,
  });

  final Player player;
  final int pos;
  final Prize? prize;
}

/// Results podium mirroring the web `ResultPodiumPage`.
class ResultPodiumScreen extends StatelessWidget {
  const ResultPodiumScreen({super.key, this.gameId});

  /// Id of the game to show; falls back to the current live game when null.
  final String? gameId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final game = gameId != null ? app.gameById(gameId!) : app.currentGame;

    if (game == null || game.status != LiveGameStatus.completed) {
      // Guard: only show the podium once the game is fully completed.
      // A null game means it was deleted; a non-completed game means the user
      // navigated here manually while the tournament is still running.
      // Use the standardized AppEmptyState for UI consistency (checklist 20-008).
      return const AppEmptyState(
        icon: Icons.emoji_events_outlined,
        title: 'Result unavailable',
        description: 'This game may have been deleted or is not finished.',
      );
    }

    final finishOrder = game.finishOrder;
    final players = game.players;
    final prizes = game.structure.prizes;
    final user = app.user;

    // Individual payout amounts are private: only organisers see them
    // (checklist 14-042, 19-020). Public completed results carry no money.
    final showAmounts = user?.isAdmin == true;

    final ranked = [
      for (var i = 0; i < finishOrder.length; i++)
        if (players.where((p) => p.id == finishOrder[i]).firstOrNull
            case final player?)
          _PodiumResult(
            player: player,
            pos: finishOrder.length - i,
            prize: prizes
                .where((pr) => pr.place == finishOrder.length - i)
                .firstOrNull,
          ),
    ];
    // finishOrder is "first-out first" so ranked is worst-first. The podium
    // shows the top three (1st/2nd/3rd), not the first three entries.
    final podium = ranked.where((r) => r.pos <= 3).toList()
      ..sort((a, b) => a.pos.compareTo(b.pos));
    final myResult = ranked.where((r) => r.player.id == user?.id || (app.hasGuestSession && app.guestSession!.gameId == game.id && r.player.name == app.guestSession!.name)).firstOrNull;
    final totalRebuys = players.fold<int>(0, (s, p) => s + p.rebuys);

    return AppPage(
      maxWidth: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero header
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: Column(
              children: [
                Icon(
                  Icons.emoji_events,
                  size: AppFontSizes.displayLg,
                  color: AppColors.icon,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  game.settings.name,
                  textAlign: TextAlign.center,
                  style: AppTypography.crimsonShimmer(
                    size: AppFontSizes.display,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${game.settings.date} · ${game.settings.location}',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '${game.settings.name} prize pool',
                      style: AppTypography.monoSm.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Podium visual
          if (podium.isNotEmpty)
            SizedBox(
              height: 220,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final vi in [1, 0, 2])
                    if (vi < podium.length)
                      Expanded(
                        child: _PodiumSlot(
                          result: podium[vi],
                          isWinner: vi == 0,
                          showAmounts: showAmounts,
                        ),
                      ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          // My result banner
          if (myResult != null)
            AppCard(
              glow: myResult.pos <= 3,
              borderColor: myResult.pos <= 3
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : null,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your result',
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      _medalFor(myResult.pos, AppFontSizes.xxxl),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              myResult.pos == 1
                                  ? 'Winner!'
                                  : '${myResult.pos}${_ordinal(myResult.pos)} place',
                              style: AppTypography.display(
                                size: AppFontSizes.xl,
                                weight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${players.length} players entered',
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (myResult.prize != null && showAmounts)
                        Text(
                          Formatters.chips(myResult.prize!.amount),
                          style: AppTypography.monoXl.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          if (myResult != null && app.isGuest) ...[
            AppAlertBanner(
              type: AppAlertType.info,
              message: 'Save this result to your permanent record.',
              actionLabel: 'Create Account',
              onAction: () => _showCreateAccountDialog(context, app),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          // Full results table
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.md,
                ),
                child: Text(
                  'FULL RESULTS',
                  style: AppTypography.bodyXs.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Column(
                  children: [
                    for (final entry in ranked.asMap().entries)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        color: entry.value.player.id == user?.id
                            ? AppColors.primarySoft
                            : (entry.key % 2 == 0 ? AppColors.card : AppColors.background),
                        child: Row(
                          children: [
                            SizedBox(
                          width: 32,
                          child: entry.value.pos <= 3
                              ? MedalIcon(entry.value.pos, size: AppFontSizes.lg)
                              : Text(
                                  '#${entry.value.pos}',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.monoSm.copyWith(
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.avatarColorFor(entry.value.player.name),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            entry.value.player.name.trim().isEmpty
                                ? '?'
                                : entry.value.player.name.trim()[0].toUpperCase(),
                            style: AppTypography.bodyXs.copyWith(
                              color: AppColors.foreground,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  entry.value.player.name,
                                  style: AppTypography.bodySm.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (entry.value.player.id == user?.id) ...[
                                const SizedBox(width: AppSpacing.xs),
                                const AppBadge(
                                  label: 'You',
                                  variant: AppBadgeVariant.green,
                                ),
                              ],
                              if (entry.value.player.isGuest) ...[
                                const SizedBox(width: AppSpacing.xs),
                                const AppBadge(
                                  label: 'Guest',
                                  variant: AppBadgeVariant.muted,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (showAmounts) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            [
                              if (entry.value.player.rebuys > 0) '${entry.value.player.rebuys}R',
                              if (entry.value.player.hasAddOn) 'AO',
                              if (entry.value.player.knockouts > 0)
                                '${entry.value.player.knockouts} KO',
                            ].join(' · '),
                            style: AppTypography.bodyXs.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          showAmounts && entry.value.prize != null
                              ? Formatters.chips(entry.value.prize!.amount)
                              : '—',
                          style: AppTypography.monoSm.copyWith(
                            color: showAmounts && entry.value.prize != null
                                ? AppColors.primary
                                : AppColors.mutedForeground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
          const SizedBox(height: AppSpacing.md),
          // Stats
          if (showAmounts)
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Players',
                    value: '${players.length}',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatCard(
                    label: 'Total pot',
                    value: Formatters.chips(game.structure.prizePool),
                    valueColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatCard(label: 'Rebuys', value: '$totalRebuys'),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Players',
                    value: '${players.length}',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatCard(
                    label: 'Duration',
                    value:
                        '${game.settings.durationHours == game.settings.durationHours.roundToDouble() ? game.settings.durationHours.round() : game.settings.durationHours}h',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatCard(
                    label: 'Final level',
                    value: 'L${game.currentLevel}',
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  variant: AppButtonVariant.secondary,
                  onPressed: () => context.go(RoutePaths.group),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_back,
                        size: 14,
                        color: AppColors.icon,
                      ),
                      const SizedBox(width: 6),
                      const Text('Group'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  onPressed: () => context.go(RoutePaths.home),
                  child: const Text('Home'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _medalFor(int pos, double size) {
    if (pos <= 3) return MedalIcon(pos, size: size);
    return Text(
      '#$pos',
      style: AppTypography.monoSm.copyWith(color: AppColors.mutedForeground),
    );
  }

  String _ordinal(int pos) {
    if (pos == 1) return 'st';
    if (pos == 2) return 'nd';
    if (pos == 3) return 'rd';
    return 'th';
  }

  void _showCreateAccountDialog(BuildContext context, AppProvider app) {
    final name = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final err = await app.convertGuestAccount(
                name.text.trim(),
                email.text.trim(),
                password.text,
              );
              if (!ctx.mounted) return;
              if (err != null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(err)),
                );
                return;
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Create Account'),
          ),
        ],
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot({
    required this.result,
    required this.isWinner,
    required this.showAmounts,
  });

  final _PodiumResult result;
  final bool isWinner;
  final bool showAmounts;

  @override
  Widget build(BuildContext context) {
    // Heights must stay well under the parent SizedBox(220) minus the medal
    // row (~32px) so the winner column never triggers a RenderFlex overflow.
    final heights = [150.0, 118.0, 86.0];
    final labels = ['1st', '2nd', '3rd'];
    final isFirst = result.pos == 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          MedalIcon(result.pos, size: AppFontSizes.xxxl),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
              border: Border.all(
                color: isFirst
                    ? AppColors.gold.withValues(alpha: 0.5)
                    : AppColors.border,
              ),
            ),
            height: heights[result.pos - 1],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  result.player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.display(
                    size: AppFontSizes.md,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  labels[result.pos - 1],
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                if (result.prize != null && showAmounts)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      Formatters.chips(result.prize!.amount),
                      style: AppTypography.monoSm.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
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

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.monoLg.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.foreground,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
