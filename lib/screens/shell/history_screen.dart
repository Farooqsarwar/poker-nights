import 'package:flutter/material.dart';
import '../../app/typography.dart';
import '../../app/colors.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/route_paths.dart';
import '../../constants/app_constants.dart';
import '../../models/cash_game.dart';
import '../../models/live_game.dart';
import '../../providers/app_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_page.dart';
import '../../widgets/page_header.dart';
import '../../widgets/medal_icon.dart';
import '../../responsive/responsive.dart';

/// History + leaderboard mirroring B7_History.png mobile-first layout.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _tab = 'all';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final group = app.currentGroup;
    final pastGames = group.pastGames;
    final userId = app.user?.id;
    final isAdmin = app.isAdmin;

    final myGames = pastGames
        .where((g) => g.players.any((p) => p.id == userId))
        .toList();
    final myStats = _computeMyStats(myGames, userId);
    final isMobile = AppBreakpoints.deviceOf(context).isMobile;

    return AppPage.slivers(
      maxWidth: 760,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                onBack: () => context.go(RoutePaths.group),
                title: 'History',
              ),
              const SizedBox(height: AppSpacing.md),
              // Filter pills row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterPill(
                      label: 'ALL',
                      active: _tab == 'all',
                      onTap: () => setState(() => _tab = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: 'TOURNAMENTS',
                      active: _tab == 'tournaments',
                      onTap: () => setState(() => _tab = 'tournaments'),
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: 'CASH',
                      active: _tab == 'cash',
                      onTap: () => setState(() => _tab = 'cash'),
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: 'LEADERBOARD',
                      active: _tab == 'leaderboard',
                      onTap: () => setState(() => _tab = 'leaderboard'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Personal stats
              GridView.count(
                crossAxisCount: isMobile ? 3 : 5,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: isMobile ? 1.4 : 1.1,
                children: [
                  _MiniStat(label: 'Played', value: '${myStats.played}'),
                  _MiniStat(label: 'Wins', value: '${myStats.wins}'),
                  _MiniStat(label: 'Podium', value: '${myStats.podium}'),
                  _MiniStat(
                    label: 'Avg finish',
                    value: myStats.played == 0
                        ? '—'
                        : myStats.avgFinish.toStringAsFixed(1),
                  ),
                  _MiniStat(label: 'KOs', value: '${myStats.knockouts}'),
                ],
              ),
              // Admin P&L row
              if (isAdmin) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Organizer P&L',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        Formatters.money('', myStats.totalPnl),
                        style: TextStyle(
                          color: myStats.totalPnl >= 0
                              ? AppColors.successText
                              : AppColors.destructiveText,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          fontFeatures: AppTypography.numericFeatures,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
        if (_tab == 'all')
          _buildAll(pastGames, app.cashHistory, userId, isAdmin)
        else if (_tab == 'tournaments')
          _buildGames(pastGames, userId, isAdmin)
        else if (_tab == 'cash')
          _buildCash(app.cashHistory, isAdmin)
        else
          SliverToBoxAdapter(child: _buildLeaderboard(pastGames, userId)),
      ],
    );
  }

  ({
    int played,
    int wins,
    int podium,
    double avgFinish,
    int knockouts,
    double totalPnl,
  })
  _computeMyStats(List<LiveGame> myGames, String? userId) {
    var played = 0, wins = 0, podium = 0, knockouts = 0;
    var totalPlacements = 0;
    var placedGames = 0;
    double totalPnl = 0;
    for (final g in myGames) {
      played++;
      final pos = g.finishOrder.indexOf(userId ?? '');
      if (pos >= 0) {
        final placement = g.finishOrder.length - pos;
        totalPlacements += placement;
        placedGames++;
        if (placement == 1) wins++;
        if (placement <= 3) podium++;
      }
      final me = g.players.where((p) => p.id == userId).firstOrNull;
      if (me != null) {
        knockouts += me.knockouts;
      }
      final prize = g.structure.prizes
          .where(
            (pr) => pr.place == (pos >= 0 ? g.finishOrder.length - pos : -1),
          )
          .fold<int>(0, (s, pr) => s + pr.amount);
      final cost =
          g.settings.buyIn +
          (g.settings.rebuyCost ?? g.settings.buyIn) * (me?.rebuys ?? 0) +
          (g.settings.addOnCost ?? g.settings.buyIn) *
              ((me?.hasAddOn ?? false) ? 1 : 0);
      totalPnl += prize - cost;
    }
    final avgFinish = placedGames == 0 ? 0.0 : totalPlacements / placedGames;
    return (
      played: played,
      wins: wins,
      podium: podium,
      avgFinish: avgFinish,
      knockouts: knockouts,
      totalPnl: totalPnl,
    );
  }

  Widget _buildAll(
    List<LiveGame> pastGames,
    List<CashSession> cashHistory,
    String? userId,
    bool isAdmin,
  ) {
    if (pastGames.isEmpty && cashHistory.isEmpty) {
      return SliverToBoxAdapter(
        child: _emptyCard(
          icon: Icons.history,
          message: 'No completed games yet.',
        ),
      );
    }
    return SliverList.builder(
      itemCount: pastGames.length + cashHistory.length,
      itemBuilder: (context, i) {
        if (i < pastGames.length) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _HistoryRow(
              game: pastGames[i],
              userId: userId,
              showAmounts: isAdmin,
            ),
          );
        }
        final cashIndex = i - pastGames.length;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _CashHistoryRow(
            session: cashHistory[cashIndex],
            showAmounts: isAdmin,
          ),
        );
      },
    );
  }

  Widget _buildGames(List<LiveGame> pastGames, String? userId, bool isAdmin) {
    if (pastGames.isEmpty) {
      return SliverToBoxAdapter(
        child: _emptyCard(
          icon: Icons.style_outlined,
          message: 'No completed tournaments yet.',
        ),
      );
    }
    return SliverList.builder(
      itemCount: pastGames.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _HistoryRow(
          game: pastGames[i],
          userId: userId,
          showAmounts: isAdmin,
        ),
      ),
    );
  }

  Widget _buildCash(List<CashSession> sessions, bool isAdmin) {
    if (sessions.isEmpty) {
      return SliverToBoxAdapter(
        child: _emptyCard(
          icon: Icons.payments_outlined,
          message: 'No completed cash games yet.',
        ),
      );
    }
    return SliverList.builder(
      itemCount: sessions.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _CashHistoryRow(session: sessions[i], showAmounts: isAdmin),
      ),
    );
  }

  Widget _emptyCard({required IconData icon, required String message}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.mutedForeground),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: TextStyle(color: AppColors.mutedForeground, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboard(List<LiveGame> pastGames, String? userId) {
    final statsMap = <String, _LbEntry>{};
    for (final game in pastGames) {
      for (final p in game.players.where((p) => !p.isGuest)) {
        final entry = statsMap.putIfAbsent(p.id, () => _LbEntry(name: p.name));
        entry.played++;
        entry.knockouts += p.knockouts;
      }
      final winnerId = game.finishOrder.isNotEmpty
          ? game.finishOrder.last
          : null;
      if (winnerId != null && statsMap.containsKey(winnerId)) {
        statsMap[winnerId]!.wins++;
      }
      final top3 = game.finishOrder.reversed.take(3);
      for (final id in top3) {
        if (statsMap.containsKey(id)) {
          statsMap[id]!.podium++;
        }
      }
    }
    final sorted = statsMap.entries.toList()
      ..sort((a, b) {
        final w = b.value.wins.compareTo(a.value.wins);
        if (w != 0) return w;
        final p = b.value.podium.compareTo(a.value.podium);
        if (p != 0) return p;
        return b.value.played.compareTo(a.value.played);
      });

    if (sorted.isEmpty) {
      return _emptyCard(
        icon: Icons.leaderboard_outlined,
        message: 'No completed games yet.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          for (var i = 0; i < sorted.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: i < sorted.length - 1
                    ? Border(bottom: BorderSide(color: AppColors.borderSubtle))
                    : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: i < 3
                        ? MedalIcon(i + 1, size: 18)
                        : Text(
                            '#${i + 1}',
                            style: TextStyle(
                              color: AppColors.mutedForeground,
                              fontSize: 12,
                              fontFeatures: AppTypography.numericFeatures,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            sorted[i].value.name,
                            style: TextStyle(
                              color: AppColors.foreground,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (sorted[i].key == userId) ...[
                          const SizedBox(width: 8),
                          const AppBadge(
                            label: 'You',
                            variant: AppBadgeVariant.green,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _LbStat(value: '${sorted[i].value.wins}', label: 'wins'),
                      const SizedBox(width: 14),
                      _LbStat(
                        value: '${sorted[i].value.podium}',
                        label: 'podium',
                      ),
                      const SizedBox(width: 14),
                      _LbStat(
                        value: '${sorted[i].value.played}',
                        label: 'played',
                      ),
                      if (sorted[i].value.knockouts > 0) ...[
                        const SizedBox(width: 14),
                        _LbStat(
                          value: '${sorted[i].value.knockouts}',
                          label: 'KOs',
                        ),
                      ],
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

class _FilterPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 36,
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: active ? null : Border.all(color: AppColors.borderSubtle),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.eyebrow(
            size: 11,
            color: active
                ? AppColors.primaryForeground
                : AppColors.mutedForeground,
          ),
        ),
      ),
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
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
                fontFeatures: AppTypography.numericFeatures,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: AppColors.mutedForeground),
            ),
          ),
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
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.foreground,
            fontFeatures: AppTypography.numericFeatures,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: AppColors.mutedForeground),
        ),
      ],
    );
  }
}

class _CashHistoryRow extends StatelessWidget {
  const _CashHistoryRow({required this.session, required this.showAmounts});

  final CashSession session;
  final bool showAmounts;

  @override
  Widget build(BuildContext context) {
    final currency = session.settings.currency;
    final elapsedMins = session.elapsed.inMinutes;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: AppColors.borderSubtle),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.muted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.payments_outlined,
                        size: 20,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.settings.name,
                            style: TextStyle(
                              color: AppColors.foreground,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${session.settings.date} · ${session.players.length} players',
                            style: TextStyle(
                              color: AppColors.mutedForeground,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (showAmounts)
                          Text(
                            Formatters.money(currency, session.totalBuyIns),
                            style: TextStyle(
                              color: AppColors.foreground,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              fontFeatures: AppTypography.numericFeatures,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.muted,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${elapsedMins ~/ 60}H ${elapsedMins % 60}M',
                            style: TextStyle(
                              color: AppColors.mutedForeground,
                              fontSize: 10,
                              fontFeatures: AppTypography.numericFeatures,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.game,
    required this.userId,
    required this.showAmounts,
  });

  final LiveGame game;
  final String? userId;
  final bool showAmounts;

  @override
  Widget build(BuildContext context) {
    final myPos = game.finishOrder.indexOf(userId ?? '');
    final placement = myPos >= 0 ? game.finishOrder.length - myPos : null;
    final me = game.players.where((p) => p.id == userId).firstOrNull;
    final winnerId = game.finishOrder.isNotEmpty ? game.finishOrder.last : null;
    final winner = game.players.where((p) => p.id == winnerId).firstOrNull;
    final playersCount = game.players.where((p) => !p.isGuest).length;
    final isPodium = placement != null && placement <= 3;
    final prizeForPlacement = placement == null
        ? 0
        : game.structure.prizes.isEmpty
        ? 0
        : game.structure.prizes
                  .where((pr) => pr.place == placement)
                  .firstOrNull
                  ?.amount ??
              0;
    final net = placement == null
        ? null
        : prizeForPlacement -
              game.settings.buyIn -
              ((me?.rebuys ?? 0) *
                  (game.settings.rebuyCost ?? game.settings.buyIn)) -
              ((me?.hasAddOn ?? false)
                  ? (game.settings.addOnCost ?? game.settings.buyIn)
                  : 0);

    final stripeColor = placement == 1
        ? AppColors.gold
        : isPodium
        ? AppColors.primary
        : (net != null && net > 0
              ? AppColors.successText
              : AppColors.borderSubtle);

    return InkWell(
      onTap: () {
        context.read<AppProvider>().setCurrentGame(game);
        context.go(RoutePaths.resultPodium);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: stripeColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  game.settings.name,
                                  style: TextStyle(
                                    color: AppColors.foreground,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${game.settings.date} · $playersCount players${placement != null ? ' · #$placement' : ''}',
                                  style: TextStyle(
                                    color: AppColors.mutedForeground,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (net != null && showAmounts)
                                Text(
                                  net >= 0
                                      ? '+\$${net.abs()}'
                                      : '-\$${net.abs()}',
                                  style: TextStyle(
                                    color: net >= 0
                                        ? AppColors.successText
                                        : AppColors.destructiveText,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: AppTypography.numericFeatures,
                                  ),
                                )
                              else if (placement != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: placement == 1
                                        ? AppColors.gold.withValues(alpha: 0.15)
                                        : isPodium
                                        ? AppColors.primarySoft
                                        : AppColors.muted,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    placement == 1 ? '1st' : '#$placement',
                                    style: TextStyle(
                                      color: placement == 1
                                          ? AppColors.gold
                                          : isPodium
                                          ? AppColors.primaryText
                                          : AppColors.mutedForeground,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.muted,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Builder(
                                  builder: (context) {
                                    final totalMins =
                                        (game.settings.durationHours * 60)
                                            .round();
                                    final hours = totalMins ~/ 60;
                                    final mins = totalMins % 60;
                                    final durationStr = hours > 0
                                        ? '${hours}H ${mins}M'
                                        : '${mins}M';
                                    return Text(
                                      durationStr,
                                      style: TextStyle(
                                        color: AppColors.mutedForeground,
                                        fontSize: 10,
                                        fontFeatures: AppTypography.numericFeatures,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'Winner: ${winner?.name ?? '—'}',
                            style: TextStyle(
                              color: AppColors.mutedForeground,
                              fontSize: 12,
                            ),
                          ),
                          if (placement != null && placement <= 3) ...[
                            const SizedBox(width: 6),
                            MedalIcon(placement, size: 14),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
