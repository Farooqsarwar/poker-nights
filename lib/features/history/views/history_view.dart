import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:poker_night/core/widgets/pn_card.dart';
import 'package:poker_night/core/widgets/pn_empty_state.dart';
import 'package:poker_night/core/widgets/pn_loading.dart';
import 'package:poker_night/core/widgets/pn_section_header.dart';
import 'package:poker_night/features/history/controllers/history_controller.dart';
import 'package:poker_night/features/history/models/game_result_model.dart';
import 'package:poker_night/core/theme/app_colors.dart';

class HistoryView extends StatefulWidget {
  final String groupId;

  const HistoryView({super.key, required this.groupId});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  late HistoryController _controller;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<HistoryController>(tag: widget.groupId)) {
      Get.put(HistoryController(groupId: widget.groupId), tag: widget.groupId);
    }
    _controller = Get.find<HistoryController>(tag: widget.groupId);
    Future.microtask(() {
      _controller.loadHistory();
    });
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      appBar: AppBar(title: const Text('Game History'), backgroundColor: AppColors.darkSurface),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Obx(() {
            final isLoading = _controller.isLoading.value;
            final games = _controller.games;
            if (isLoading) {
              return const PNLoading(message: 'Loading history...');
            }

            return RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.cardDark,
              onRefresh: () => _controller.loadHistory(),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  _buildStatisticsSection(theme, games),
                  const PNSectionHeader(title: 'Game History'),
                  if (games.isEmpty)
                    const PNEmptyState(
                      icon: Icons.history,
                      title: 'No games played yet',
                      subtitle: 'Completed games will appear here.',
                    )
                  else
                    ...games.map((game) => _buildGameCard(game, theme)),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildStatisticsSection(ThemeData theme, List<GameResult> games) {
    final gamesPlayed = games.length;
    final wins = games.where((g) => g.positions.any((p) => p.position == 1)).length;
    final podiums = games.where((g) => g.positions.any((p) => p.position <= 3)).length;
    final avgFinish = gamesPlayed > 0 ? games.fold(0.0, (sum, g) {
      final pos = g.positions.where((p) => p.position > 0);
      return sum + (pos.isNotEmpty ? pos.first.position.toDouble() : 0);
    }) / gamesPlayed : 0.0;
    final knockouts = games.fold(0, (sum, g) => sum + g.knockouts.values.fold(0, (a, b) => a + b));

    return Column(
      children: [
        const PNSectionHeader(title: 'Group Statistics'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildStatCard('Games', '$gamesPlayed', Icons.play_circle, theme),
              const SizedBox(width: 12),
              _buildStatCard('Wins', '$wins', Icons.emoji_events, theme),
              const SizedBox(width: 12),
              _buildStatCard('Podiums', '$podiums', Icons.star, theme),
              const SizedBox(width: 12),
              _buildStatCard('Avg', avgFinish.toStringAsFixed(1), Icons.trending_up, theme),
              const SizedBox(width: 12),
              _buildStatCard('KOs', '$knockouts', Icons.sports_kabaddi, theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, ThemeData theme) {
    return PNCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Icon(icon, color: AppColors.accent, size: 24),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildGameCard(GameResult game, ThemeData theme) {
    final winner = game.positions.where((p) => p.position == 1).firstOrNull;
    return PNCard(
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      onTap: () => _showGameDetails(game, theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(game.gameName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: Colors.white))),
              Text(_formatDate(game.completedAt), style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.people, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('${game.playerCount} players', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              const Spacer(),
              if (winner != null) ...[
                const Icon(Icons.emoji_events, size: 16, color: AppColors.gold),
                const SizedBox(width: 4),
                Text(winner.playerName, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: AppColors.gold)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _buildPodium(game.positions, theme),
        ],
      ),
    );
  }

  Widget _buildPodium(List<FinalPosition> positions, ThemeData theme) {
    final podium = positions.where((p) => p.position >= 1 && p.position <= 3).toList()..sort((a, b) => a.position.compareTo(b.position));
    if (podium.isEmpty) return const SizedBox.shrink();

    const medals = ['1st', '2nd', '3rd'];
    final colors = [AppColors.gold, Colors.grey.shade400, Colors.brown.shade300];

    return Row(
      children: List.generate(podium.length, (index) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index < podium.length - 1 ? 8 : 0),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              color: colors[index].withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors[index].withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(medals[index], style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: colors[index], fontSize: 11)),
                const SizedBox(width: 4),
                Flexible(child: Text(podium[index].playerName, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500, color: Colors.white))),
              ],
            ),
          ),
        );
      }),
    );
  }

  void _showGameDetails(GameResult game, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.85,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            final sortedPositions = List<FinalPosition>.from(game.positions)..sort((a, b) => a.position.compareTo(b.position));

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 16),
                  Text(game.gameName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('${_formatDate(game.completedAt)}  ·  ${game.playerCount} players', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 20),
                  Text('Final Standings', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: sortedPositions.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: Colors.white12),
                      itemBuilder: (context, index) {
                        final pos = sortedPositions[index];
                        const medal = ['1st', '2nd', '3rd'];
                        final prefix = index < 3 ? medal[index] : '#${pos.position}';
                        return ListTile(
                          dense: true,
                          leading: Text(prefix, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: index < 3 ? AppColors.gold : Colors.white70)),
                          title: Text(pos.playerName, style: const TextStyle(color: Colors.white)),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
