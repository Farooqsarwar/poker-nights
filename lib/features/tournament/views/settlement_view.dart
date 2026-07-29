import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/core/widgets/pn_button.dart';
import 'package:poker_night/features/auth/controllers/auth_controller.dart';
import 'package:poker_night/features/live_game/controllers/live_game_controller.dart';
import 'package:poker_night/features/tournament/controllers/settlement_controller.dart';
import 'package:poker_night/features/tournament/models/settlement_model.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:poker_night/core/theme/app_colors.dart';
import 'package:poker_night/core/widgets/pn_card.dart';

class SettlementView extends StatefulWidget {
  final String groupId;
  final String gameId;

  const SettlementView({super.key, required this.groupId, required this.gameId});

  @override
  State<SettlementView> createState() => _SettlementViewState();
}

class _SettlementViewState extends State<SettlementView> {
  late final SettlementController _settlementController;
  late final AuthController _authController;
  final _positionControllers = <int, TextEditingController>{};
  final _playerNameControllers = <int, TextEditingController>{};
  bool _initialized = false;
  
  @override
  void initState() {
    super.initState();
    _authController = Get.find<AuthController>();
    if (Get.isRegistered<SettlementController>(tag: widget.gameId)) {
      _settlementController = Get.find<SettlementController>(tag: widget.gameId);
    } else {
      _settlementController = Get.put(SettlementController(widget.gameId), tag: widget.gameId);
    }
  }

  @override
  void dispose() {
    for (final c in _positionControllers.values) {
      c.dispose();
    }
    for (final c in _playerNameControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initializeControllers(List<FinalPosition>? positions) {
    if (_initialized) return;
    _initialized = true;

    if (positions != null && positions.isNotEmpty) {
      for (final p in positions) {
        _positionControllers[p.position] = TextEditingController(text: p.payout.toString());
        _playerNameControllers[p.position] = TextEditingController(text: p.participantName);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final currentUser = _authController.currentUser.value;
      final settlement = _settlementController.settlement.value;
      
      // Sort positions by placement
      final positions = (settlement?.finalPositions ?? []).toList()
        ..sort((a, b) => a.position.compareTo(b.position));

      _initializeControllers(settlement?.finalPositions);

      return Scaffold(
        backgroundColor: AppColors.darkSurface,
        appBar: AppBar(
          backgroundColor: AppColors.darkSurface,
          title: const Text('Final Settlement', style: TextStyle(fontFamily: 'Inter', color: AppColors.textOnDark, fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: AppColors.textOnDark),
          elevation: 0,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Prize pool banner
                      PNCard(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Text(settlement?.status == const SettlementStatus.confirmed() ? 'Total Prize Pool' : 'Estimated Prize Pool',
                                  style: const TextStyle(fontFamily: 'Inter', color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Text(
                                '\$${settlement?.prizePool ?? 0}',
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.textOnDark),
                              ),
                              if (settlement != null) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: AppColors.cardDark, borderRadius: BorderRadius.circular(20)),
                                  child: Text('Organizer Amount: \$${settlement.organizerAmount}', style: const TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary, fontSize: 12)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ).animate().fade().scale(),
                      
                      const SizedBox(height: 24),
                      
                      if (positions.isEmpty)
                        const Center(child: Text('No positions recorded yet', style: TextStyle(color: AppColors.textSecondary)))
                      else
                        ...positions.map((pos) => _positionCard(pos)),

                      if (positions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _validatePayouts(settlement?.prizePool ?? 0, positions) == 0
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _validatePayouts(settlement?.prizePool ?? 0, positions) == 0
                                  ? Colors.green : Colors.red,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _validatePayouts(settlement?.prizePool ?? 0, positions) == 0
                                    ? Icons.check_circle : Icons.warning,
                                color: _validatePayouts(settlement?.prizePool ?? 0, positions) == 0
                                    ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _validatePayouts(settlement?.prizePool ?? 0, positions) == 0
                                      ? 'Payouts match prize pool'
                                      : 'Mismatch: \$${_validatePayouts(settlement?.prizePool ?? 0, positions)} remaining',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: _validatePayouts(settlement?.prizePool ?? 0, positions) == 0
                                        ? Colors.green : Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Bottom Actions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, -5))],
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: PNButton(
                            label: 'Complete Tournament',
                            onPressed: () async {
                              if (currentUser == null) return;
                              if (_validatePayouts(settlement?.prizePool ?? 0, positions) != 0) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Payouts do not match prize pool. Adjust amounts first.')),
                                  );
                                }
                                return;
                              }
                              await _settlementController.confirmSettlement(currentUser.name);
                              
                              if (Get.isRegistered<LiveGameController>(tag: widget.gameId)) {
                                final gameController = Get.find<LiveGameController>(tag: widget.gameId);
                                gameController.updatePrizePool(settlement?.prizePool ?? 0);
                              }
                              
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Settlement confirmed')),
                                );
                                context.pushReplacement('/groups/${widget.groupId}/tournament/${widget.gameId}/results');
                              }
                            },
                          ),
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
    });
  }

  Widget _positionCard(FinalPosition pos) {
    Color rankColor;
    if (pos.position == 1) {
      rankColor = AppColors.gold;
    } else if (pos.position == 2) rankColor = const Color(0xFFC0C0C0); // Silver
    else if (pos.position == 3) rankColor = const Color(0xFFCD7F32); // Bronze
    else rankColor = AppColors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pos.position <= 3 ? rankColor.withValues(alpha: 0.3) : Colors.transparent),
      ),
      child: ListTile(
        leading: Stack(
          alignment: Alignment.center,
          children: [
            if (pos.position <= 3) Icon(Icons.emoji_events, color: rankColor, size: 40)
            else CircleAvatar(backgroundColor: AppColors.primary, child: Text('#${pos.position}', style: const TextStyle(color: AppColors.textOnDark))),
            if (pos.position <= 3) Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${pos.position}', style: const TextStyle(fontFamily: 'Inter', color: AppColors.darkSurface, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
        title: Text(pos.participantName, style: const TextStyle(fontFamily: 'Inter', color: AppColors.textOnDark, fontWeight: FontWeight.w600, fontSize: 16)),
        subtitle: pos.isChop ? Text('Chop: \$${pos.chopAmount}', style: const TextStyle(fontFamily: 'Inter', color: Colors.orange, fontSize: 12)) : null,
        trailing: Text('\$${pos.payout}', style: const TextStyle(fontFamily: 'Inter', color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
    ).animate().fade().slideX();
  }
}

int _validatePayouts(int prizePool, List<FinalPosition> positions) {
  final total = positions.fold(0, (sum, p) => sum + p.payout);
  return prizePool - total;
}
