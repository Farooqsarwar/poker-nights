import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/live_game.dart';
import '../../providers/app_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_progress_bar.dart';

/// Detailed statistics mirroring the account area of the web app.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final user = app.user;

    if (user == null) {
      return AppPage(
        child: Column(
          children: [
            Text(
              'Sign in to see your statistics.',
              style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
            ),
          ],
        ),
      );
    }

    return AppPage(
      maxWidth: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Statistics', style: AppTypography.display(size: AppFontSizes.xxxl, weight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${user.name} · all-time results',
            style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Headline cards
          GridView.count(
            crossAxisCount: 6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.1,
            children: [
              _HeadlineStat(label: 'Played', value: '${user.stats.played}'),
              _HeadlineStat(label: 'Wins', value: '${user.stats.wins}', accent: AppColors.gold),
              _HeadlineStat(label: 'Podium', value: '${user.stats.podium}'),
              _HeadlineStat(label: 'Avg finish', value: '#${user.stats.avgFinish.toStringAsFixed(1)}'),
              _HeadlineStat(label: 'Knockouts', value: '${user.stats.knockouts}'),
              _HeadlineStat(label: 'Win rate', value: '${_pct(user.stats.wins, user.stats.played)}%'),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          // Rates
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RateRow(
                  label: 'Win rate',
                  value: '${_pct(user.stats.wins, user.stats.played)}%',
                  progress: _rate(user.stats.wins, user.stats.played),
                  color: AppProgressColor.primary,
                ),
                const SizedBox(height: AppSpacing.lg),
                _RateRow(
                  label: 'Podium rate',
                  value: '${_pct(user.stats.podium, user.stats.played)}%',
                  progress: _rate(user.stats.podium, user.stats.played),
                  color: AppProgressColor.success,
                ),
                const SizedBox(height: AppSpacing.lg),
                _RateRow(
                  label: 'Casualty rate',
                  value: '${user.stats.knockouts} KO',
                  progress: (user.stats.knockouts / (user.stats.played * 6)).clamp(0.0, 1.0),
                  color: AppProgressColor.destructive,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Recent results', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          _RecentResults(app: app, userId: user.id),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  int _pct(int part, int total) => total == 0 ? 0 : ((part / total) * 100).round();

  double _rate(int part, int total) => total == 0 ? 0 : (part / total).clamp(0.0, 1.0);
}

class _HeadlineStat extends StatelessWidget {
  const _HeadlineStat({required this.label, required this.value, this.accent});

  final String label;
  final String value;
  final Color? accent;

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
              style: AppTypography.mono(
                size: AppFontSizes.lg,
                weight: FontWeight.w700,
                color: accent ?? AppColors.foreground,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
        ],
      ),
    );
  }
}

class _RateRow extends StatelessWidget {
  const _RateRow({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  final String label;
  final String value;
  final double progress;
  final AppProgressColor color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
              value,
              style: AppTypography.mono(size: AppFontSizes.sm, weight: FontWeight.w700, color: AppColors.foreground),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppProgressBar(value: progress, max: 1, color: color),
      ],
    );
  }
}

class _RecentResults extends StatelessWidget {
  const _RecentResults({required this.app, required this.userId});

  final AppProvider app;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final medals = const ['🥇', '🥈', '🥉'];
    final pastGames = app.currentGroup.pastGames;
    final mine = pastGames
        .where((g) => g.players.any((p) => p.id == userId))
        .take(6)
        .toList();

    if (mine.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          children: [
            const Text('🃏', style: TextStyle(fontSize: AppFontSizes.xxxl)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No completed games yet. Finish a tournament and your results will show here.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
            ),
          ],
        ),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < mine.length; i++)
            _ResultRow(
              game: mine[i],
              userId: userId,
              medals: medals,
              showDivider: i < mine.length - 1,
            ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.game,
    required this.userId,
    required this.medals,
    required this.showDivider,
  });

  final LiveGame game;
  final String userId;
  final List<String> medals;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final myPos = game.finishOrder.indexOf(userId);
    final placement = myPos >= 0 ? game.finishOrder.length - myPos : null;
    final net = _netFor(game, placement);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: showDivider ? const Border(bottom: BorderSide(color: AppColors.border)) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              placement == null
                  ? '—'
                  : placement <= 3
                      ? medals[placement - 1]
                      : '#$placement',
              textAlign: TextAlign.center,
              style: placement != null && placement > 3
                  ? AppTypography.mono(size: AppFontSizes.sm, weight: FontWeight.w600)
                  : const TextStyle(fontSize: AppFontSizes.sm),
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
                  game.settings.date,
                  style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                ),
              ],
            ),
          ),
          if (net != null)
            Text(
              Formatters.signedMoney('\$', net.toDouble()),
              style: AppTypography.mono(
                size: AppFontSizes.sm,
                weight: FontWeight.w700,
                color: net >= 0 ? AppColors.success : AppColors.destructive,
              ),
            ),
        ],
      ),
    );
  }

  int? _netFor(LiveGame game, int? placement) {
    if (placement == null) return null;
    // Prize lookup by placement; unpaid placements simply earn 0 (they still
    // paid the buy-in).
    final prize = game.structure.prizes
        .where((pr) => pr.place == placement)
        .firstOrNull
        ?.amount ??
        0;
    return prize - game.settings.buyIn;
  }
}
