import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/game.dart';
import '../../models/tournament.dart';
import '../../providers/app_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/medal_icon.dart';

/// Record finish order mirroring the web `CompleteTournamentPage`.
class CompleteTournamentScreen extends StatefulWidget {
  const CompleteTournamentScreen({super.key});

  @override
  State<CompleteTournamentScreen> createState() =>
      _CompleteTournamentScreenState();
}

class _CompleteTournamentScreenState extends State<CompleteTournamentScreen> {
  final List<String> _order = [];
  bool _confirmed = false;

  void _finishPlayer(String playerId) {
    setState(() {
      if (!_order.contains(playerId)) _order.add(playerId);
    });
  }

  void _undo() {
    setState(() => _order.removeLast());
  }

  void _confirm(AppProvider app) {
    // finishOrder is "first-out first": players already eliminated during play
    // (tracked by eliminationPos) come first, then the tapped survivors.
    final game = app.currentGame;
    final eliminated = game!.players.where((p) => p.eliminated).toList()
      ..sort(
        (a, b) => (b.eliminationPos ?? 0).compareTo(a.eliminationPos ?? 0),
      );
    app.recordFinishOrder([...eliminated.map((p) => p.id), ..._order]);
    setState(() => _confirmed = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) context.go(RoutePaths.resultPodium);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    // Spec §3.3: Only admin can complete a tournament.
    if (!app.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Admin access required.')),
      );
    }

    final game = app.currentGame;

    if (game == null) {
      // No game in provider — redirect back to dashboard instead of
      // showing a blank screen dead-end.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(RoutePaths.adminDashboard);
      });
      return const SizedBox.shrink();
    }

    final activePlayers = game.activePlayers;
    final prizes = game.structure.prizes;

    // Players eliminated during play, in first-out order (their elimination
    // position is the count of active players remaining at the time).
    final eliminated = game.players.where((p) => p.eliminated).toList()
      ..sort(
        (a, b) => (b.eliminationPos ?? 0).compareTo(a.eliminationPos ?? 0),
      );

    final unranked = activePlayers
        .where((p) => !_order.contains(p.id))
        .toList();
    final ranked = <_RankedPlayer>[
      for (final p in eliminated)
        _RankedPlayer(
          player: p,
          pos: p.eliminationPos ?? activePlayers.length + 1,
          prize: _prizeFor(prizes, p.eliminationPos ?? 0),
        ),
      for (var i = 0; i < _order.length; i++)
        _RankedPlayer(
          player: game.players.where((p) => p.id == _order[i]).firstOrNull,
          pos: activePlayers.length - i,
          prize: _prizeFor(prizes, activePlayers.length - i),
        ),
    ];

    return AppPage(
      maxWidth: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => context.go(RoutePaths.adminDashboard),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xs),
                  child: Icon(
                    Icons.arrow_back,
                    size: AppFontSizes.xl,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Record Finish Order',
                    style: AppTypography.display(
                      size: AppFontSizes.xxxl,
                      weight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Tap players in order of elimination (first-out first)',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_confirmed)
            AppCard(
              glow: true,
              padding: const EdgeInsets.all(AppSpacing.xxxl),
              child: Column(
                children: [
                  Icon(
                    Icons.emoji_events,
                    size: AppFontSizes.displayLg,
                    color: AppColors.icon,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Tournament Complete!',
                    style: AppTypography.crimsonShimmer(size: AppFontSizes.xxl),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Loading results\u2026',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // Still playing
            if (unranked.isNotEmpty)
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Still playing (${unranked.length})',
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final p in unranked)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: InkWell(
                          onTap: () => _finishPlayer(p.id),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: AppColors.avatarPalette.first,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    p.name.trim().isEmpty
                                        ? '?'
                                        : p.name.trim()[0].toUpperCase(),
                                    style: AppTypography.bodyXs.copyWith(
                                      color: AppColors.foreground,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Text(
                                    p.name,
                                    style: AppTypography.bodySm.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'tap to finish',
                                      style: AppTypography.bodyXs.copyWith(
                                        color: AppColors.mutedForeground,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward,
                                      size: 12,
                                      color: AppColors.icon,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (unranked.length == 1)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Center(
                          child: Text(
                            'Last player \u2014 tap to set as winner!',
                            style: AppTypography.bodyXs.copyWith(
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            // Finish order
            if (ranked.isNotEmpty)
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Finish order',
                          style: AppTypography.bodyXs.copyWith(
                            color: AppColors.mutedForeground,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: _undo,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.undo,
                                size: 14,
                                color: AppColors.destructive,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Undo last',
                                style: AppTypography.bodyXs.copyWith(
                                  color: AppColors.destructive,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final r in ranked.reversed)
                      if (r.player != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.muted.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: r.pos <= 3
                                      ? Center(
                                          child: MedalIcon(
                                            r.pos,
                                            size: AppFontSizes.xl,
                                          ),
                                        )
                                      : Text(
                                          '#${r.pos}',
                                          textAlign: TextAlign.center,
                                          style: AppTypography.bodyXs.copyWith(
                                            color: AppColors.mutedForeground,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    r.player!.name,
                                    style: AppTypography.bodySm.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (r.prize != null)
                                  Text(
                                    Formatters.chips(r.prize!.amount),
                                    style: AppTypography.monoSm.copyWith(
                                      color: AppColors.primary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            // Prize breakdown
            if (prizes.isNotEmpty)
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prize distribution (admin only)',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (var i = 0; i < prizes.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _placeName(prizes[i].place),
                                style: AppTypography.bodySm.copyWith(
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ),
                            Text(
                              Formatters.chips(prizes[i].amount),
                              style: AppTypography.monoSm.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              size: AppButtonSize.lg,
              fullWidth: true,
              onPressed: unranked.isEmpty ? () => _confirm(app) : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.emoji_events,
                    size: 16,
                    color: AppColors.icon,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    unranked.isEmpty
                        ? 'Record results'
                        : '${unranked.length} player${unranked.length > 1 ? 's' : ''} left to rank',
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  String _placeName(int place) => switch (place) {
    1 => '1st place',
    2 => '2nd place',
    3 => '3rd place',
    _ => '${place}th place',
  };

  Prize? _prizeFor(List<Prize> prizes, int pos) {
    if (pos <= 0) return null;
    return prizes.where((p) => p.place == pos).firstOrNull;
  }
}

class _RankedPlayer {
  const _RankedPlayer({
    required this.player,
    required this.pos,
    required this.prize,
  });

  final Player? player;
  final int pos;
  final Prize? prize;
}
