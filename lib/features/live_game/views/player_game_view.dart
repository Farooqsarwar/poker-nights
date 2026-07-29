import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:poker_night/core/widgets/pn_timer_display.dart';
import 'package:poker_night/core/widgets/pn_card.dart';
import 'package:poker_night/features/live_game/controllers/live_game_controller.dart';
import 'package:poker_night/features/live_game/models/game_state_model.dart';
import 'package:poker_night/services/storage_service.dart';
import 'package:poker_night/services/voice_service.dart';

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
            color: controller.remainingSeconds < 60 ? Colors.red : null,
          ),
          const SizedBox(height: 4),
          Text(
            'Level ${gameState.currentLevel}${isRunning ? '' : ' (PAUSED)'}',
            style: theme.textTheme.titleSmall?.copyWith(
              color: isRunning ? Colors.grey : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlindsSection(ThemeData theme, GameState gameState) {
    return PNCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        children: [
          PNBlindsDisplay(
            smallBlind: gameState.currentBlinds.smallBlind,
            bigBlind: gameState.currentBlinds.bigBlind,
            ante: gameState.currentBlinds.ante,
            fontSize: 28,
          ),
        ],
      ),
    );
  }

  Widget _buildNextLevelSection(ThemeData theme, GameState gameState) {
    final next = gameState.nextBlinds;
    return PNCard(
      child: Row(
        children: [
          const Icon(Icons.skip_next, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Next Level'),
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
    );
  }

  Widget _buildPlayerInfoSection(ThemeData theme, PlayerState player) {
    return PNCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: theme.colorScheme.primary.withAlpha(30),
            child: Text(
              '${player.seatNo}',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.name, style: theme.textTheme.titleMedium),
                Text(
                  'Seat ${player.seatNo}',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
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
                  color: theme.colorScheme.primary,
                ),
              ),
              Text('Stack', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
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
    );
  }

  Widget _buildPrizePoolSection(ThemeData theme, GameState gameState) {
    return PNCard(
      child: Row(
        children: [
          const Icon(Icons.monetization_on, color: Colors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Prize Pool'),
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
    );
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
