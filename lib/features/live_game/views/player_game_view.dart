import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:poker_night/core/widgets/pn_timer_display.dart';
import 'package:poker_night/core/widgets/pn_card.dart';
import 'package:poker_night/features/live_game/controllers/live_game_controller.dart';
import 'package:poker_night/features/live_game/models/game_state_model.dart';
import 'package:poker_night/services/storage_service.dart';
import 'package:poker_night/services/voice_service.dart';
import 'package:poker_night/core/theme/app_colors.dart';

class PlayerGameView extends StatelessWidget {
  final String tournamentId;
  final String playerId;
  final bool isGuest;

  const PlayerGameView({
    super.key,
    required this.tournamentId,
    required this.playerId,
    this.isGuest = false,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<LiveGameController>(tag: tournamentId)
        ? Get.find<LiveGameController>(tag: tournamentId)
        : Get.put(LiveGameController(Get.find<StorageService>(), Get.find<VoiceService>(), tournamentId), tag: tournamentId);
    final theme = Theme.of(context);

    return Obx(() {
      final gameState = controller.state;
      final player = gameState.players.firstWhere(
      (p) => p.id == playerId,
      orElse: () => PlayerState(
        id: playerId,
        name: 'Unknown',
        tableNo: 0,
        seatNo: 0,
        stack: 0,
        status: 'active',
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(gameState.gameId),
        actions: [
          if (!isGuest)
            IconButton(
              icon: const Icon(Icons.chat),
              tooltip: 'Chat',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat is available from the group page'), duration: Duration(seconds: 2)),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.fullscreen),
            tooltip: 'Fullscreen',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fullscreen mode toggled'), duration: Duration(seconds: 1)),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTimerSection(theme, gameState, controller),
            const SizedBox(height: 12),
            _buildBlindsSection(theme, gameState),
            const SizedBox(height: 12),
            _buildNextLevelSection(theme, gameState),
            const SizedBox(height: 12),
            _buildPlayerInfoSection(theme, player),
            const SizedBox(height: 12),
            _buildStatsSection(gameState),
            const SizedBox(height: 12),
            _buildPrizePoolSection(theme, gameState),
          ],
        ),
      ),
        ),
      ),
    );
  });
}

  Widget _buildTimerSection(ThemeData theme, GameState gameState, LiveGameController controller) {
    final isRunning = controller.isRunning;

    return PNCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        children: [
          PNTimerDisplay(
            seconds: controller.remainingSeconds,
            fontSize: 48,
            showLabel: true,
            color: controller.remainingSeconds < 60 ? Colors.red : AppColors.primary,
          ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 4),
          Text(
            'Level ${gameState.currentLevel}${isRunning ? '' : ' (PAUSED)'}',
            style: theme.textTheme.titleSmall?.copyWith(
              color: isRunning ? Colors.grey : Colors.red,
            ),
          ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0);
  }

  Widget _buildBlindsSection(ThemeData theme, GameState gameState) {
    return PNCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        children: [
          Text(
            'CURRENT BLINDS',
            style: theme.textTheme.titleSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          PNBlindsDisplay(
            smallBlind: gameState.currentBlinds.smallBlind,
            bigBlind: gameState.currentBlinds.bigBlind,
            ante: gameState.currentBlinds.ante,
            fontSize: 28,
          ).animate(key: ValueKey('player_blinds_${gameState.currentLevel}')).fadeIn().scale(),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildNextLevelSection(ThemeData theme, GameState gameState) {
    final next = gameState.nextBlinds;
    return PNCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, shape: BoxShape.circle),
            child: const Icon(Icons.skip_next, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Next Level', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                PNBlindsDisplay(
                  smallBlind: next.smallBlind,
                  bigBlind: next.bigBlind,
                  ante: next.ante,
                  fontSize: 16,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildPlayerInfoSection(ThemeData theme, PlayerState player) {
    return PNCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withAlpha(30),
            child: Text(
              '${player.seatNo}',
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text(
                  'Seat ${player.seatNo}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${player.stack}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              Text('Stack', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.05, end: 0);
  }

  Widget _buildStatsSection(GameState gameState) {
    return PNCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(Icons.people, 'Players Left', '${gameState.playersRemaining}'),
          _statItem(Icons.bar_chart, 'Avg Stack', '\$${gameState.averageStack}'),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildPrizePoolSection(ThemeData theme, GameState gameState) {
    return PNCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.monetization_on, color: Colors.amber, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Prize Pool', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                Text(
                  '\$${gameState.prizePool}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _statItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
