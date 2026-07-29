import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/core/theme/app_colors.dart';
import 'package:poker_night/features/auth/controllers/auth_controller.dart';
import 'package:poker_night/features/tournament/controllers/tournament_controller.dart';
import 'package:poker_night/features/tournament/controllers/tournament_engine.dart';
import 'package:poker_night/features/tournament/models/blind_structure_model.dart';
import 'package:poker_night/features/tournament/models/tournament_model.dart';
import 'package:poker_night/core/widgets/pn_button.dart';

class StructureReviewView extends StatefulWidget {
  final String groupId;
  final String gameId;

  const StructureReviewView({super.key, required this.groupId, required this.gameId});

  @override
  State<StructureReviewView> createState() => _StructureReviewViewState();
}

class _StructureReviewViewState extends State<StructureReviewView> {
  final _authController = Get.find<AuthController>();
  final _tournamentController = Get.find<TournamentController>();
  BlindStructure? _structure;
  TournamentModel? _tournament;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final userId = _authController.currentUser.value?.id ?? '';
    if (userId.isEmpty) return;
    final tournaments = _tournamentController.tournaments;
    final tournament = tournaments.where((t) => t.id == widget.gameId).firstOrNull;
    if (tournament != null) {
      _tournament = tournament;
      _structure = TournamentEngine.generate(tournament.settings, null);
    }
    setState(() => _loading = false);
  }

  void _confirmPublished() {
    _tournamentController.updateStatus(widget.gameId, TournamentStatus.published);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tournament published!'), duration: Duration(seconds: 2)),
    );
    context.go('/groups/${widget.groupId}/tournament/${widget.gameId}/admin');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.darkSurface,
        appBar: AppBar(title: const Text('Blind Structure', style: TextStyle(color: AppColors.textPrimary)), backgroundColor: AppColors.darkSurface),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final levels = _structure?.levels ?? [];
    final predictedFinishLevel = _structure?.predictedFinishLevel ?? 0;
    final startingStack = _structure?.startingStack ?? 0;
    final totalChips = _structure?.startingStackChips ?? 0;
    final players = _tournament?.settings.expectedPlayers ?? 0;
    final estimatedDuration = levels.fold(0, (sum, l) => sum + l.durationMinutes);

    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        title: Text(_tournament?.name ?? 'Blind Structure', style: const TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          PopupMenuButton<String>(
            iconColor: AppColors.textPrimary,
            color: AppColors.cardDark,
            onSelected: (v) {
              if (v == 'back') context.pop();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'back', child: ListTile(leading: Icon(Icons.arrow_back, color: AppColors.textPrimary), title: Text('Back to Edit', style: TextStyle(color: AppColors.textPrimary)), dense: true)),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.darkSurface,
                child: Row(
                  children: [
                    _summaryChip(theme, 'Starting Stack', '\$$startingStack'),
                    const SizedBox(width: 12),
                    _summaryChip(theme, 'Total Chips', totalChips.toString()),
                    const SizedBox(width: 12),
                    _summaryChip(theme, 'Players', players.toString()),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.cardDark,
                child: Row(
                  children: [
                    _headerCell('Level', 50, theme),
                    _headerCell('SB', 60, theme),
                    _headerCell('BB', 60, theme),
                    _headerCell('Ante', 60, theme),
                    _headerCell('Duration', 70, theme),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: levels.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: AppColors.primary.withValues(alpha: 0.2)),
                  itemBuilder: (context, index) {
                    final level = levels[index];
                    final isFinal = level.level == predictedFinishLevel;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: isFinal ? AppColors.green.withValues(alpha: 0.1) : null,
                      child: Row(
                        children: [
                          _cell('${level.level}', 50, theme),
                          _cell('\$${level.smallBlind}', 60, theme),
                          _cell('\$${level.bigBlind}', 60, theme),
                          _cell(level.ante > 0 ? '\$${level.ante}' : '-', 60, theme),
                          _cell('${level.durationMinutes}m', 70, theme),
                          if (isFinal)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Icon(Icons.flag, size: 16, color: AppColors.green),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.cardDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Predicted finish: Level $predictedFinishLevel', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
                    Text('Estimated duration: ${estimatedDuration ~/ 60}h ${estimatedDuration % 60}m', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    if (_structure != null && _structure!.chipExchanges.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Chip Exchanges', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                      ..._structure!.chipExchanges.map((e) => Text('Level ${e.atLevel}: ${e.instruction}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: PNButton(
                        onPressed: _confirmPublished,
                        label: 'Publish & Start',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PNButton(
                        onPressed: () => context.pop(),
                        label: 'Back to Edit',
                        outlined: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryChip(ThemeData theme, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(String text, double width, ThemeData theme) {
    return SizedBox(
      width: width,
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary)),
    );
  }

  Widget _cell(String text, double width, ThemeData theme) {
    return SizedBox(width: width, child: Text(text, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)));
  }
}
