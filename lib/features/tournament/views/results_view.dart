import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/features/tournament/controllers/settlement_controller.dart';
import 'package:poker_night/features/tournament/models/settlement_model.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:poker_night/core/theme/app_colors.dart';
import 'package:poker_night/core/widgets/pn_button.dart';
import 'package:poker_night/core/widgets/pn_card.dart';

class ResultsView extends StatefulWidget {
  final String groupId;
  final String gameId;

  const ResultsView({super.key, required this.groupId, required this.gameId});

  @override
  State<ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<ResultsView> {
  late final SettlementController _settlementController;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<SettlementController>(tag: widget.gameId)) {
      _settlementController = Get.find<SettlementController>(tag: widget.gameId);
    } else {
      _settlementController = Get.put(SettlementController(widget.gameId), tag: widget.gameId);
    }
    Future.microtask(() {
      _settlementController.loadSettlement();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final settlement = _settlementController.settlement.value;

      if (settlement == null) {
        return Scaffold(
          backgroundColor: AppColors.darkSurface,
          appBar: AppBar(backgroundColor: AppColors.darkSurface, title: const Text('Final Results')),
          body: const Center(child: Text('No results available', style: TextStyle(color: AppColors.textOnDark))),
        );
      }
      
      final positions = settlement.finalPositions.toList()
        ..sort((a, b) => a.position.compareTo(b.position));

      return Scaffold(
        backgroundColor: AppColors.darkSurface,
        appBar: AppBar(
          backgroundColor: AppColors.darkSurface,
          title: const Text('Final Results', style: TextStyle(fontFamily: 'Inter', color: AppColors.textOnDark, fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: AppColors.textOnDark),
          elevation: 0,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Celebration header
                Center(
                  child: Column(
                    children: [
                      const Text('🎉', style: TextStyle(fontSize: 48)).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
                      const SizedBox(height: 8),
                      const Text('Tournament Complete!', style: TextStyle(fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textOnDark)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Winner Podium
                if (positions.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (positions.length > 1) _podiumItem(positions[1], 2, 120),
                      const SizedBox(width: 8),
                      _podiumItem(positions[0], 1, 160),
                      const SizedBox(width: 8),
                      if (positions.length > 2) _podiumItem(positions[2], 3, 100),
                    ],
                  ).animate().fade().slideY(begin: 0.5),
                  
                const SizedBox(height: 32),
                
                // Full Results Table
                PNCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Full Standings', style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textOnDark)),
                      ),
                      const Divider(color: AppColors.primary, height: 1),
                      ...positions.map((pos) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: AppColors.primary.withValues(alpha: 0.5))),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 30,
                              child: Text('#${pos.position}', style: const TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                            ),
                            Expanded(
                              child: Text(pos.participantName, style: const TextStyle(fontFamily: 'Inter', color: AppColors.textOnDark, fontWeight: FontWeight.w500)),
                            ),
                            Text('\$${pos.payout}', style: const TextStyle(fontFamily: 'Inter', color: Colors.green, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )),
                    ],
                  ),
                ).animate().fade().slideY(begin: 0.2, delay: 200.ms),
                
                const SizedBox(height: 24),
                
                // Actions
                PNButton(
                  icon: Icons.share,
                  label: 'Share Results',
                  onPressed: () {},
                ),
                const SizedBox(height: 12),
                PNButton(
                  label: 'Back to Group',
                  outlined: true,
                  onPressed: () => context.go('/groups/${widget.groupId}'),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
  
  Widget _podiumItem(FinalPosition pos, int rank, double height) {
    Color color;
    if (rank == 1) {
      color = AppColors.gold;
    } else if (rank == 2) color = const Color(0xFFC0C0C0);
    else color = const Color(0xFFCD7F32);
    
    return Column(
      children: [
        Icon(Icons.emoji_events, color: color, size: rank == 1 ? 48 : 32),
        const SizedBox(height: 8),
        Text(pos.participantName, style: const TextStyle(fontFamily: 'Inter', color: AppColors.textOnDark, fontWeight: FontWeight.bold)),
        Text('\$${pos.payout}', style: const TextStyle(fontFamily: 'Inter', color: Colors.green, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          width: 80,
          height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 8),
          child: Text('$rank', style: TextStyle(fontFamily: 'Inter', color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
