import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:poker_night/core/widgets/pn_card.dart';
import 'package:poker_night/features/live_game/controllers/live_game_controller.dart';
import 'package:poker_night/features/live_game/models/game_state_model.dart';
import 'package:poker_night/services/storage_service.dart';
import 'package:poker_night/services/voice_service.dart';

class TvModeView extends StatefulWidget {
  final String tournamentId;

  const TvModeView({super.key, required this.tournamentId});

  @override
  State<TvModeView> createState() => _TvModeViewState();
}

class _TvModeViewState extends State<TvModeView> with SingleTickerProviderStateMixin {
  Timer? _reconnectTimer;
  bool _disconnected = false;
  String? _overlayMessage;
  Timer? _overlayTimer;
  AnimationController? _fadeController;
  Animation<double>? _fadeAnimation;
  int _lastLevelRef = 0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = CurvedAnimation(parent: _fadeController!, curve: Curves.easeInOut);
    _reconnectTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final controller = Get.find<LiveGameController>(tag: widget.tournamentId);
      controller.recoverFromLocal();
      if (_disconnected) {
        setState(() => _disconnected = false);
      }
    });
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _overlayTimer?.cancel();
    _fadeController?.dispose();
    super.dispose();
  }

  void _showOverlay(String message) {
    setState(() => _overlayMessage = message);
    _fadeController?.forward();
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 4), () {
      _fadeController?.reverse();
      _overlayTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _overlayMessage = null);
      });
    });
  }

  static const _darkBg = Color(0xFF0D0D0D);

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<LiveGameController>(tag: widget.tournamentId)
        ? Get.find<LiveGameController>(tag: widget.tournamentId)
        : Get.put(LiveGameController(Get.find<StorageService>(), Get.find<VoiceService>(), widget.tournamentId), tag: widget.tournamentId);

    return Obx(() {
      final gameState = controller.state;
    final nextLevel = gameState.nextBlinds;

    final isSettlement = gameState.status == 'paused' && gameState.currentLevel > 1;
    if (_lastLevelRef != gameState.currentLevel) {
      _lastLevelRef = gameState.currentLevel;
      _showOverlay('Level ${gameState.currentLevel} started');
    }
    if (gameState.status == 'completed' && _lastLevelRef != -1) {
      _lastLevelRef = -1;
      _showOverlay('Tournament Complete');
    }

    return Scaffold(
      backgroundColor: _darkBg,
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 1200;
                final isShort = constraints.maxHeight < 600;
                final isFinalTable = gameState.playersRemaining <= 9 &&
                    gameState.playersRemaining > 0;

                if (isShort) {
                  return _buildCompactLayout(context, gameState, nextLevel);
                }

                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: _buildMainColumn(context, gameState, nextLevel, isFinalTable),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 3,
                              child: _buildSidePanel(context, gameState, isFinalTable),
                            ),
                          ],
                        )
                      : _buildMainColumn(context, gameState, nextLevel, isFinalTable),
                );
              },
            ),
          ),
          if (_disconnected)
            Positioned(top: 0, left: 0, right: 0, child: Container(
              color: Colors.red.shade900.withAlpha(200),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: const Text('DISCONNECTED — Stale data shown', textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            )),
          if (isSettlement)
            Positioned(top: 0, left: 0, right: 0, child: Container(
              color: Colors.orange.shade900.withAlpha(200),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: const Text('SETTLEMENT BREAK', textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            )),
          if (_overlayMessage != null)
            FadeTransition(
              opacity: _fadeAnimation ?? AlwaysStoppedAnimation(1),
              child: Positioned.fill(
                child: Container(
                  color: Colors.black87,
                  child: Center(
                    child: Text(_overlayMessage!, style: const TextStyle(
                      fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 4,
                    ), textAlign: TextAlign.center),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    });
  }

  Widget _buildMainColumn(BuildContext context, GameState gameState, BlindLevelData? nextLevel, bool isFinalTable) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: 4, child: Center(child: Text(
          gameState.pausedRemainingSeconds.toString(),
          style: TextStyle(fontSize: 160, color: gameState.status == 'running' ? Colors.white : Colors.grey),
        ))),
        const SizedBox(height: 8),
        Text('LEVEL ${gameState.currentLevel}${gameState.status == 'running' ? '' : ' — PAUSED'}',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: Colors.white54, letterSpacing: 6),
        ),
        const SizedBox(height: 16),
        Expanded(flex: 3, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _tvBlindBox('\$${gameState.currentBlinds.smallBlind}', 'SB', Colors.orange),
          const SizedBox(width: 48),
          _tvBlindBox('\$${gameState.currentBlinds.bigBlind}', 'BB', Colors.deepOrange),
          if (gameState.currentBlinds.ante > 0) ...[
            const SizedBox(width: 48),
            _tvBlindBox('\$${gameState.currentBlinds.ante}', 'ANTE', Colors.purple),
          ],
        ])),
        const SizedBox(height: 16),
        if (nextLevel != null)
          _tvCard(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.skip_next, color: Colors.white70, size: 28),
              const SizedBox(width: 12),
              Text('NEXT: ', style: _tvStyle(20, fontWeight: FontWeight.w300)),
              Text('SB \$${nextLevel.smallBlind}  /  BB \$${nextLevel.bigBlind}${nextLevel.ante > 0 ? '  /  Ante \$${nextLevel.ante}' : ''}',
                  style: _tvStyle(24, fontWeight: FontWeight.w600)),
            ]),
          )),
      ],
    );
  }

  Widget _buildSidePanel(BuildContext context, GameState gameState, bool isFinalTable) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _tvCard(child: Padding(padding: const EdgeInsets.all(20), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PLAYERS', style: _tvSectionLabel()),
        const SizedBox(height: 8),
        Text('${gameState.playersRemaining}', style: _tvStyle(56, fontWeight: FontWeight.w900)),
        Text('of ${gameState.players.length} remaining', style: _tvStyle(16, color: Colors.grey)),
      ]))),
      const SizedBox(height: 12),
      _tvCard(child: Padding(padding: const EdgeInsets.all(20), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('AVG STACK', style: _tvSectionLabel()),
        const SizedBox(height: 8),
        Text('\$${_formatNumber(gameState.averageStack)}', style: _tvStyle(40, fontWeight: FontWeight.w800)),
      ]))),
      const SizedBox(height: 12),
      _tvCard(child: Padding(padding: const EdgeInsets.all(20), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.monetization_on, color: Colors.amber, size: 24),
          const SizedBox(width: 8),
          Text('PRIZE POOL', style: _tvSectionLabel()),
        ]),
        const SizedBox(height: 8),
        Text('\$${_formatNumber(gameState.prizePool.toInt())}',
            style: _tvStyle(40, fontWeight: FontWeight.w800, color: Colors.amber)),
      ]))),
      const SizedBox(height: 12),
      if (isFinalTable)
        _tvCard(child: Padding(padding: const EdgeInsets.all(20), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('FINAL TABLE', style: _tvSectionLabel()),
          const SizedBox(height: 8),
          ...gameState.players.where((p) => p.status != 'eliminated').take(9).toList().asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final player = entry.value;
            return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
              SizedBox(width: 24, child: Text('$rank.', style: _tvStyle(18, fontWeight: FontWeight.w700, color: rank <= 3 ? Colors.amber : Colors.white70))),
              Expanded(child: Text(player.name, style: _tvStyle(18), overflow: TextOverflow.ellipsis)),
              Text('\$${_formatNumber(player.stack)}', style: _tvStyle(18, fontWeight: FontWeight.w600, color: Colors.green)),
            ]));
          }),
        ])))
      else
        _tvCard(child: Padding(padding: const EdgeInsets.all(20), child: Text('Poker Night', style: _tvStyle(24, fontWeight: FontWeight.w600)))),
    ]);
  }

  Widget _buildCompactLayout(BuildContext context, GameState gameState, BlindLevelData? nextLevel) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Row(children: [
      Expanded(flex: 3, child: Text(
        gameState.pausedRemainingSeconds.toString(),
        style: TextStyle(fontSize: 72, color: gameState.status == 'running' ? Colors.white : Colors.grey),
      )),
      const SizedBox(width: 16),
      Expanded(flex: 2, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('L ${gameState.currentLevel}', style: _tvStyle(28, fontWeight: FontWeight.w700)),
        Text('\$${gameState.currentBlinds.smallBlind}/\$${gameState.currentBlinds.bigBlind}${gameState.currentBlinds.ante > 0 ? '/\$${gameState.currentBlinds.ante}' : ''}',
            style: _tvStyle(24, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('${gameState.playersRemaining} players', style: _tvStyle(18, color: Colors.grey)),
        if (nextLevel != null)
          Text('Next: \$${nextLevel.smallBlind}/\$${nextLevel.bigBlind}', style: _tvStyle(16, color: Colors.grey)),
      ])),
    ]));
  }

  Widget _tvBlindBox(String value, String label, Color color) {
    return Column(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withAlpha(100), width: 3)),
        child: Text(value, style: TextStyle(fontSize: 72, fontWeight: FontWeight.w900, color: color, letterSpacing: 2))),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white54, letterSpacing: 4)),
    ]);
  }

  Widget _tvCard({required Widget child}) {
    return PNCard(
      child: child,
    );
  }

  TextStyle _tvStyle(double size, {FontWeight fontWeight = FontWeight.w400, Color color = Colors.white}) {
    return TextStyle(fontSize: size, fontWeight: fontWeight, color: color, letterSpacing: 1);
  }

  TextStyle _tvSectionLabel() {
    return const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white38, letterSpacing: 3);
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}
