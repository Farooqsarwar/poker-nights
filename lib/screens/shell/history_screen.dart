import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/live_game.dart';
import '../../providers/app_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_tabs.dart';

/// History + leaderboard mirroring the web `HistoryPage`.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _tab = 'games';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final group = app.currentGroup;
    final pastGames = group.pastGames;
    final userId = app.user?.id;
    final medals = const ['🥇', '🥈', '🥉'];

    final myGames = pastGames.where((g) => g.players.any((p) => p.id == userId)).toList();
    final myStats = _computeMyStats(myGames, userId);

    return AppPage(
      maxWidth: 760,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('History', style: AppTypography.display(size: AppFontSizes.xxxl, weight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${group.name} · all past tournaments',
            style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Personal stats
          GridView.count(
            crossAxisCount: 6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.1,
            children: [
              _MiniStat(label: 'Played', value: '${myStats.played}'),
              _MiniStat(label: 'Wins', value: '${myStats.wins}'),
              _MiniStat(label: 'Podium', value: '${myStats.podium}'),
              _MiniStat(label: 'Rebuys', value: '${myStats.rebuys}'),
              _MiniStat(label: 'KOs', value: '${myStats.knockouts}'),
              _MiniStat(
                label: 'P&L',
                value: '${myStats.earnings >= 0 ? '+' : ''}${Formatters.chips(myStats.earnings)}',
                color: myStats.earnings >= 0 ? AppColors.success : AppColors.destructive,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTabs(
            tabs: const [
              AppTabItem(id: 'games', label: 'Games'),
              AppTabItem(id: 'leaderboard', label: 'Leaderboard'),
            ],
            active: _tab,
            onChanged: (t) => setState(() => _tab = t),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_tab == 'games')
            _buildGames(pastGames, userId, medals)
          else
            _buildLeaderboard(pastGames, userId, medals),
        ],
      ),
    );
  }

  ({int played, int wins, int podium, int rebuys, int knockouts, double earnings}) _computeMyStats(
      List<LiveGame> myGames, String? userId) {
    var played = 0, wins = 0, podium = 0, rebuys = 0, knockouts = 0;
    var earnings = 0.0;
    for (final g in myGames) {
      played++;
      final pos = g.finishOrder.indexOf(userId ?? '');
      if (pos >= 0) {
        final placement = g.finishOrder.length - pos;
        if (placement == 1) wins++;
        if (placement <= 3) podium++;
        // Prize lookup is by placement (result_podium convention), never an
        // index into an arbitrary-length list; missing payouts earn 0.
        final prize = g.structure.prizes.isEmpty
            ? 0
            : g.structure.prizes
                    .where((pr) => pr.place == placement)
                    .firstOrNull
                    ?.amount ??
                0;
        earnings += prize - g.settings.buyIn;
      }
      final me = g.players.where((p) => p.id == userId).firstOrNull;
      if (me != null) {
        rebuys += me.rebuys;
        knockouts += me.knockouts;
      }
    }
    return (played: played, wins: wins, podium: podium, rebuys: rebuys, knockouts: knockouts, earnings: earnings);
  }

  Widget _buildGames(List<LiveGame> pastGames, String? userId, List<String> medals) {
    if (pastGames.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          children: [
            const Text('🃏', style: TextStyle(fontSize: AppFontSizes.xxxl)),
            const SizedBox(height: AppSpacing.sm),
            Text('No completed games yet.', style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final game in pastGames) ...[
          _HistoryRow(game: game, userId: userId, medals: medals),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  Widget _buildLeaderboard(List<LiveGame> pastGames, String? userId, List<String> medals) {
    final statsMap = <String, _LbEntry>{};
    for (final game in pastGames) {
      for (final p in game.players) {
        final entry = statsMap.putIfAbsent(p.id, () => _LbEntry(name: p.name));
        entry.played++;
        entry.knockouts += p.knockouts;
        final pos = game.finishOrder.indexOf(p.id);
        final placement = pos >= 0 ? game.finishOrder.length - pos : null;
        if (placement == 1) entry.wins++;
        if (placement != null && placement <= 3) entry.podium++;
      }
    }
    final sorted = statsMap.entries.toList()..sort((a, b) {
      final w = b.value.wins.compareTo(a.value.wins);
      if (w != 0) return w;
      final p = b.value.podium.compareTo(a.value.podium);
      if (p != 0) return p;
      return b.value.played.compareTo(a.value.played);
    });

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Text('All-time standings', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
          ),
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Text(
                'No data yet.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
              ),
            )
          else
            for (var i = 0; i < sorted.length; i++)
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: sorted[i].key == userId ? AppColors.primary.withValues(alpha: 0.04) : Colors.transparent,
                  border: i < sorted.length - 1
                      ? const Border(bottom: BorderSide(color: AppColors.border))
                      : null,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        i < 3 ? medals[i] : '#${i + 1}',
                        textAlign: TextAlign.center,
                        style: i < 3 ? null : AppTypography.mono(size: AppFontSizes.xs, color: AppColors.mutedForeground),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.avatarColorFor(sorted[i].value.name),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        sorted[i].value.name.isEmpty ? '?' : sorted[i].value.name[0].toUpperCase(),
                        style: AppTypography.bodyXs.copyWith(fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              sorted[i].value.name,
                              style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (sorted[i].key == userId) ...[
                            const SizedBox(width: AppSpacing.sm),
                            const AppBadge(label: 'You', variant: AppBadgeVariant.green),
                          ],
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        _LbStat(value: '${sorted[i].value.wins}', label: 'wins'),
                        const SizedBox(width: AppSpacing.lg),
                        _LbStat(value: '${sorted[i].value.podium}', label: 'podium'),
                        const SizedBox(width: AppSpacing.lg),
                        _LbStat(value: '${sorted[i].value.played}', label: 'played'),
                      ],
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _LbEntry {
  _LbEntry({required this.name});

  final String name;
  int played = 0;
  int wins = 0;
  int podium = 0;
  int knockouts = 0;
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppTypography.mono(size: AppFontSizes.lg, weight: FontWeight.w700, color: color ?? AppColors.foreground),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
        ],
      ),
    );
  }
}

class _LbStat extends StatelessWidget {
  const _LbStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTypography.mono(size: AppFontSizes.sm, weight: FontWeight.w700, color: AppColors.foreground)),
        Text(label, style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground, fontSize: 10)),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.game, required this.userId, required this.medals});

  final LiveGame game;
  final String? userId;
  final List<String> medals;

  @override
  Widget build(BuildContext context) {
    final myPos = game.finishOrder.indexOf(userId ?? '');
    final placement = myPos >= 0 ? game.finishOrder.length - myPos : null;
    final winnerId = game.finishOrder.isNotEmpty ? game.finishOrder.last : null;
    final winner = game.players.where((p) => p.id == winnerId).firstOrNull;
    final playersCount = game.players.where((p) => !p.isGuest).length;
    final totalRebuys = game.players.fold<int>(0, (s, p) => s + p.rebuys);

    return AppCard(
      onTap: () => context.go(RoutePaths.resultPodium),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                alignment: Alignment.center,
                child: Text(
                  placement == 1 ? '🥇' : placement == 2 ? '🥈' : placement == 3 ? '🥉' : '🃏',
                  style: const TextStyle(fontSize: AppFontSizes.xl),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.settings.name,
                      style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${game.settings.date} · $playersCount players',
                      style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (placement != null)
                    Text(
                      placement == 1 ? '🥇 1st' : '#$placement',
                      style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
                    ),
                  if (game.structure.prizePool > 0)
                    Text(
                      Formatters.chips(game.structure.prizePool),
                      style: AppTypography.mono(size: AppFontSizes.xs, color: AppColors.primary),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Winner: ${winner?.name ?? '—'}',
                style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
              ),
              if (totalRebuys > 0)
                Text(
                  '· $totalRebuys rebuys',
                  style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                ),
              if (placement != null && placement <= 3)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Text(
                    medals[placement - 1],
                    style: const TextStyle(fontSize: AppFontSizes.xs),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
