import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:poker_night/core/widgets/pn_timer_display.dart';
import 'package:poker_night/core/widgets/pn_button.dart';
import 'package:poker_night/core/widgets/pn_card.dart';
import 'package:poker_night/core/widgets/pn_qr_display.dart';
import 'package:poker_night/core/widgets/pn_responsive_layout.dart';
import 'package:poker_night/core/widgets/pn_section_header.dart';
import 'package:poker_night/features/live_game/controllers/live_game_controller.dart';
import 'package:poker_night/features/live_game/models/game_state_model.dart';
import 'package:poker_night/services/storage_service.dart';
import 'package:poker_night/services/voice_service.dart';
import 'package:poker_night/core/theme/app_colors.dart';

class AdminGameView extends StatelessWidget {
  final String tournamentId;
  final String? groupId;

  const AdminGameView({super.key, required this.tournamentId, this.groupId});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<LiveGameController>(tag: tournamentId)
        ? Get.find<LiveGameController>(tag: tournamentId)
        : Get.put(LiveGameController(Get.find<StorageService>(), Get.find<VoiceService>(), tournamentId), tag: tournamentId);
    final theme = Theme.of(context);

    return Obx(() {
      final gameState = controller.state;
      return Scaffold(
      appBar: AppBar(
        title: Text('Game ${gameState.gameId}'),
        actions: [
          if (groupId != null)
            IconButton(
              icon: const Icon(Icons.event_seat),
              onPressed: () => context.push('/groups/$groupId/tournament/$tournamentId/seating'),
              tooltip: 'Seating',
            ),
          IconButton(
            icon: const Icon(Icons.tv),
            onPressed: () => context.push('/game/$tournamentId/tv'),
            tooltip: 'Open TV Mode',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Share Game Links',
            onPressed: () => _showShareDialog(context, tournamentId, gameState.gameId, gameState.players.length),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: PNResponsiveLayout(
        mobile: _buildMobile(context, theme, gameState, controller),
        tablet: _buildWide(context, theme, gameState, controller),
          desktop: _buildWide(context, theme, gameState, controller),
          ),
        ),
      ),
    );
  });
}

  Widget _buildMobile(
    BuildContext context,
    ThemeData theme,
    GameState gameState,
    LiveGameController controller,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildTimerSection(context, theme, gameState, controller),
          _buildBlindsSection(theme, gameState),
          _buildNextLevelSection(theme, gameState),
          _buildStatsSection(theme, gameState),
          _buildPrizePoolSection(theme, gameState),
          _buildPlayerPanel(theme, gameState, controller),
        ],
      ),
    );
  }

  Widget _buildWide(
    BuildContext context,
    ThemeData theme,
    GameState gameState,
    LiveGameController controller,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildTimerSection(context, theme, gameState, controller),
                _buildBlindsSection(theme, gameState),
                _buildNextLevelSection(theme, gameState),
                _buildStatsSection(theme, gameState),
                _buildPrizePoolSection(theme, gameState),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 320,
          child: _buildPlayerPanel(theme, gameState, controller),
        ),
      ],
    );
  }

  Widget _buildTimerSection(
    BuildContext context,
    ThemeData theme,
    GameState gameState,
    LiveGameController controller,
  ) {
    final isPending = gameState.status == 'pending';
    final isRunning = controller.isRunning;
    final isPaused = controller.isPaused;
    final isCompleted = gameState.status == 'completed';

    return PNCard(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (isPending) ...[
            _buildPreStartChecklist(theme, gameState, controller),
            const SizedBox(height: 16),
          ],
          if (!isPending) ...[
            PNTimerDisplay(
              seconds: controller.remainingSeconds,
              fontSize: 64,
              showLabel: true,
              color: controller.remainingSeconds < 60 ? Colors.red : AppColors.primary,
            ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 12),
          ],
          if (!isCompleted) Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isPending)
                PNButton(
                  label: 'Start',
                  icon: Icons.play_arrow,
                  onPressed: () => controller.startGame(),
                )
              else if (isPaused)
                PNButton(
                  label: 'Resume',
                  icon: Icons.play_arrow,
                  onPressed: () => controller.resumeGame(),
                )
              else if (isRunning)
                PNButton(
                  label: 'Pause',
                  icon: Icons.pause,
                  onPressed: () => controller.pauseGame(),
                ),
              const SizedBox(width: 8),
              PNButton(
                label: 'Advance',
                icon: Icons.skip_next,
                outlined: true,
                onPressed: () => controller.advanceLevel(),
              ),
            ],
          ),
          if (isCompleted) ...[
            Icon(Icons.check_circle, size: 64, color: Colors.green).animate().scale(delay: 200.ms),
            const SizedBox(height: 8),
            Text('Game Completed', style: theme.textTheme.titleLarge?.copyWith(color: Colors.green)).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 16),
            PNButton(
              label: 'Reopen Game',
              icon: Icons.lock_open,
              outlined: true,
              onPressed: () => controller.reopenGame(),
            ).animate().fadeIn(delay: 600.ms),
          ],
          if (!isCompleted && !isPending) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                PNButton(
                  label: 'Speed Up',
                  icon: Icons.fast_forward,
                  outlined: true,
                  onPressed: () => _showPacePreview(context, controller, 'speedUp'),
                ),
                PNButton(
                  label: 'Slow Down',
                  icon: Icons.fast_rewind,
                  outlined: true,
                  onPressed: () => _showPacePreview(context, controller, 'slowDown'),
                ),
                if (controller.canUndo)
                  PNButton(
                    label: 'Undo',
                    icon: Icons.undo,
                    outlined: true,
                    onPressed: () => controller.undoLastAction(),
                  ),
              ],
            ),
            if (!isPending) ...[
              const SizedBox(height: 16),
              PNButton(
                label: 'End Rebuy Period',
                icon: Icons.shopping_cart_checkout,
                outlined: true,
                onPressed: () => _showSettlementDialog(context, controller, gameState),
              ),
            ],
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0);
  }

  Widget _buildPreStartChecklist(ThemeData theme, GameState gameState, LiveGameController controller) {
    final checks = <MapEntry<String, bool>>[
      MapEntry('Players checked in', gameState.players.where((p) => p.status == 'active').length >= 2),
      MapEntry('Blind structure loaded', gameState.currentBlinds.bigBlind > 0),
      MapEntry('Seating confirmed', gameState.tables.isNotEmpty && gameState.tables.every((t) => t.playerCount > 0)),
      MapEntry('Prize pool set', gameState.prizePool > 0),
    ];
    final allPassed = checks.every((c) => c.value);
    return Column(
      children: [
        Text('Pre-Start Checklist', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...checks.map((c) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(c.value ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 18, color: c.value ? Colors.green : Colors.grey),
              const SizedBox(width: 8),
              Text(c.key, style: TextStyle(color: c.value ? Colors.green : Colors.grey.shade600, fontSize: 14)),
            ],
          ),
        )),
        if (!allPassed) ...[
          const SizedBox(height: 8),
          Text('Complete all checks before starting', style: TextStyle(color: Colors.orange.shade700, fontSize: 13)),
        ],
      ],
    );
  }

  Widget _buildBlindsSection(ThemeData theme, GameState gameState) {
    return PNCard(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Text(
            'LEVEL ${gameState.currentLevel}',
            style: theme.textTheme.titleMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          PNBlindsDisplay(
            smallBlind: gameState.currentBlinds.smallBlind,
            bigBlind: gameState.currentBlinds.bigBlind,
            ante: gameState.currentBlinds.ante,
            fontSize: 32,
          ).animate(key: ValueKey('blinds_${gameState.currentLevel}')).fadeIn().scale(),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildNextLevelSection(ThemeData theme, GameState gameState) {
    final next = gameState.nextBlinds;
    return PNCard(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, shape: BoxShape.circle),
            child: const Icon(Icons.skip_next, color: AppColors.primary),
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
                  fontSize: 18,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildStatsSection(ThemeData theme, GameState gameState) {
    return PNCard(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(theme, 'Players Left', '${gameState.playersRemaining}'),
          _statItem(theme, 'Avg Stack', '\$${gameState.averageStack}'),
          _statItem(theme, 'Total Chips', '\$${gameState.totalChips}'),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildPrizePoolSection(ThemeData theme, GameState gameState) {
    return PNCard(
      margin: const EdgeInsets.all(16),
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
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildPlayerPanel(
    ThemeData theme,
    GameState gameState,
    LiveGameController controller,
  ) {
    final players = gameState.players;

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PNSectionHeader(title: 'Players (${players.length})'),
          Expanded(
            child: ListView.separated(
              itemCount: players.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final player = players[index];
                final isEliminated = player.status == 'eliminated';

                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: isEliminated ? Colors.red.shade100 : Colors.green.shade100,
                    child: Text(
                      '${player.seatNo}',
                      style: TextStyle(
                        color: isEliminated ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(player.name, style: theme.textTheme.bodyMedium),
                  subtitle: isEliminated
                      ? const Text('Eliminated', style: TextStyle(color: Colors.red))
                      : Text('\$${player.stack}', style: theme.textTheme.bodySmall),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) {
                      switch (action) {
                        case 'eliminate':
                          controller.eliminatePlayer(player.id);
                          break;
                        case 'rebuy':
                          controller.rebuyPlayer(player.id);
                          break;
                        case 'reentry':
                          controller.reentryPlayer(player.id);
                          break;
                        case 'addon':
                          controller.addOnPlayer(player.id);
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      if (!isEliminated) const PopupMenuItem(value: 'eliminate', child: Text('Eliminate')),
                      if (isEliminated) ...[
                        const PopupMenuItem(value: 'rebuy', child: Text('Rebuy')),
                        const PopupMenuItem(value: 'reentry', child: Text('Re-Entry')),
                      ],
                      if (!isEliminated) const PopupMenuItem(value: 'addon', child: Text('Add-On')),
                    ],
                    icon: const Icon(Icons.more_vert),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(ThemeData theme, String label, String value) {
    return Column(
      children: [
        Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
      ],
    );
  }
}

void _showSettlementDialog(BuildContext context, LiveGameController controller, GameState gameState) {
  final activePlayers = gameState.players.where((p) => p.status == 'active').toList();
  final addOnSelections = <String, bool>{};
  for (final p in activePlayers) {
    addOnSelections[p.id] = false;
  }

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.shopping_cart_checkout, size: 20),
          SizedBox(width: 8),
          Text('End of Rebuy Period'),
        ]),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('All remaining players can take an add-on before the rebuy period closes.',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 16),
                const Text('Add-On Selection', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 8),
                ...activePlayers.map((p) => CheckboxListTile(
                  value: addOnSelections[p.id] ?? false,
                  onChanged: (v) => setDialogState(() => addOnSelections[p.id] = v ?? false),
                  title: Text(p.name),
                  subtitle: Text('Stack: \$${p.stack}', style: const TextStyle(fontSize: 13)),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.trailing,
                )),
                const Divider(),
                const SizedBox(height: 8),
                const Text('Chip Exchanges', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 4),
                Text('Remove low-denomination chips from play as blinds increase.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                ...[
                  'Remove white chips at break (Level 4)',
                  'Remove red chips at break (Level 8)',
                  'Color-up blue chips to green at break (Level 12)',
                ].map((ex) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.swap_horiz, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(child: Text(ex, style: const TextStyle(fontSize: 13))),
                  ]),
                )),
              ],
            ),
          ),
        ),
        actions: [
          PNButton(onPressed: () => Navigator.pop(context), label: 'Cancel', outlined: true),
          PNButton(
            onPressed: () {
              for (final entry in addOnSelections.entries) {
                if (entry.value) controller.addOnPlayer(entry.key);
              }
              controller.pauseGame();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Rebuy period ended. Game paused.')),
              );
            },
            label: 'Apply Add-Ons & Pause',
          ),
        ],
      ),
    ),
  );
}

void _showPacePreview(BuildContext context, LiveGameController controller, String direction) {
  final preview = controller.previewPaceChange(direction);
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(children: [
        Icon(direction == 'speedUp' ? Icons.fast_forward : Icons.fast_rewind, size: 20),
        const SizedBox(width: 8),
        Text(direction == 'speedUp' ? 'Speed Up Preview' : 'Slow Down Preview'),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Current remaining: ${controller.formatTime(preview['current'] as int)}'),
        Text('Proposed remaining: ${controller.formatTime(preview['proposed'] as int)}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(preview['effect'] as String, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      ]),
      actions: [
        PNButton(onPressed: () => Navigator.pop(ctx), label: 'Cancel', outlined: true),
        PNButton(onPressed: () {
          if (direction == 'speedUp') {
            controller.speedUp();
          } else {
            controller.slowDown();
          }
          Navigator.pop(ctx);
        }, label: direction == 'speedUp' ? 'Confirm Speed Up' : 'Confirm Slow Down'),
      ],
    ),
  );
}

void _showShareDialog(BuildContext context, String tournamentId, String gameId, int playerCount) {
  final baseUrl = '';
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.share, size: 20),
          const SizedBox(width: 8),
          const Text('Share Game'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Scan QR codes or share links:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 160,
                  child: PNQrShareCard(title: 'TV Mode', path: '/game/$tournamentId/tv', baseUrl: baseUrl),
                ),
                SizedBox(
                  width: 160,
                  child: PNQrShareCard(title: 'Player Join', path: '/game/$tournamentId/player', baseUrl: baseUrl),
                ),
                SizedBox(
                  width: 160,
                  child: PNQrShareCard(title: 'Guest Join', path: '/game/$tournamentId/guest', baseUrl: baseUrl),
                ),
              ],
            ),
            if (playerCount > 0) ...[
              const SizedBox(height: 16),
              Text('$playerCount player${playerCount == 1 ? '' : 's'} currently in the game.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        PNButton(onPressed: () => Navigator.pop(ctx), label: 'Close', outlined: true),
      ],
    ),
  );
}
