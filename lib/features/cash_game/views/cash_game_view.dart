import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:poker_night/features/cash_game/models/cash_session_model.dart';
import 'package:poker_night/core/widgets/pn_button.dart';
import 'package:poker_night/core/widgets/pn_card.dart';
import 'package:poker_night/core/widgets/pn_text_field.dart';
import 'package:poker_night/core/widgets/pn_empty_state.dart';
import 'package:poker_night/core/widgets/pn_section_header.dart';
import 'package:poker_night/core/theme/app_colors.dart';
import 'package:poker_night/features/cash_game/controllers/cash_game_controller.dart';

class CashGameView extends StatefulWidget {
  final String groupId;

  const CashGameView({super.key, required this.groupId});

  @override
  State<CashGameView> createState() => _CashGameViewState();
}

class _CashGameViewState extends State<CashGameView> {
  int _selectedIndex = -1;
  late final CashGameController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(CashGameController(widget.groupId), tag: widget.groupId);
  }

  void _showCreateSessionDialog() {
    final nameCtrl = TextEditingController();
    final sbCtrl = TextEditingController(text: '1');
    final bbCtrl = TextEditingController(text: '2');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Cash Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PNTextField(label: 'Session Name', hint: 'e.g. Friday Cash Game', controller: nameCtrl),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: PNTextField(label: 'Small Blind', controller: sbCtrl, keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: PNTextField(label: 'Big Blind', controller: bbCtrl, keyboardType: TextInputType.number)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          PNButton(
            label: 'Create',
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final sb = int.tryParse(sbCtrl.text) ?? 1;
              final bb = int.tryParse(bbCtrl.text) ?? 2;
              if (name.isEmpty) return;
              await controller.createSession(name: name, smallBlind: sb, bigBlind: bb);
              Navigator.of(ctx).pop();
              setState(() => _selectedIndex = 0);
            },
          ),
        ],
      ),
    );
  }

  void _showAddPlayerDialog(CashSession session) {
    final nameCtrl = TextEditingController();
    final buyInCtrl = TextEditingController(text: '20');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Player'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PNTextField(label: 'Player Name', hint: 'Enter player name', controller: nameCtrl),
            const SizedBox(height: 12),
            PNTextField(label: 'Buy-in Amount', controller: buyInCtrl, keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          PNButton(
            label: 'Add',
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final buyIn = int.tryParse(buyInCtrl.text) ?? 0;
              if (name.isEmpty || buyIn <= 0) return;
              final pid = DateTime.now().millisecondsSinceEpoch.toString();
              await controller.addPlayer(session.id, pid, name);
              await controller.recordBuyIn(session.id, pid, buyIn);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  void _recordTopUp(CashSession session, CashPlayer player) {
    final amtCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Top-up for ${player.name}'),
        content: PNTextField(label: 'Top-up Amount', controller: amtCtrl, keyboardType: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          PNButton(
            label: 'Record',
            onPressed: () async {
              final amount = int.tryParse(amtCtrl.text) ?? 0;
              if (amount <= 0) return;
              await controller.recordTopUp(session.id, player.participantId, amount);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  void _recordCashOut(CashSession session, CashPlayer player) {
    final amtCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cash-out for ${player.name}'),
        content: PNTextField(label: 'Cash-out Amount', controller: amtCtrl, keyboardType: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          PNButton(
            label: 'Cash Out',
            onPressed: () async {
              final amount = int.tryParse(amtCtrl.text) ?? 0;
              if (amount <= 0) return;
              await controller.recordCashOut(session.id, player.participantId, amount);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  void _completeSession(CashSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Session'),
        content: const Text('Are you sure you want to complete this session? No further changes will be allowed.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          PNButton(
            label: 'Complete',
            onPressed: () async {
              await controller.closeSession(session.id);
              Navigator.of(ctx).pop();
              setState(() => _selectedIndex = -1);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isLoading = controller.isLoading.value;
      final sessions = controller.sessions;

      if (isLoading) {
        return Scaffold(
          appBar: AppBar(title: const Text('Cash Games')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }

    if (_selectedIndex >= 0 && _selectedIndex < sessions.length) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            setState(() => _selectedIndex = -1);
          }
        },
        child: _buildSessionDetail(sessions[_selectedIndex]),
      );
    }

      return Scaffold(
        appBar: AppBar(title: const Text('Cash Games')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: sessions.isEmpty ? _buildEmptyState() : _buildSessionsList(sessions),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showCreateSessionDialog,
          child: const Icon(Icons.add),
        ),
      );
    });
  }

  Widget _buildEmptyState() {
    return PNEmptyState(
      icon: Icons.attach_money,
      title: 'No cash sessions yet',
      subtitle: 'Start a new cash game session to track buy-ins and cash-outs.',
      actionLabel: 'New Session',
      onAction: _showCreateSessionDialog,
    );
  }

  Widget _buildSessionsList(List<CashSession> sessions) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sessions.length,
      itemBuilder: (_, i) {
        final session = sessions[i];
        final isActive = session.status == 'active';
        return PNCard(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          onTap: () => setState(() => _selectedIndex = i),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.accent.withValues(alpha: 0.1) : AppColors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(isActive ? Icons.style : Icons.check_circle, color: isActive ? AppColors.accent : AppColors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('\$${session.smallBlind}/\$${session.bigBlind}  ·  ${session.players.length} player${session.players.length == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              _StatusBadge(isActive: isActive),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSessionDetail(CashSession session) {
    final totalIssued = session.players.fold(0, (sum, p) => sum + p.buyIn + p.topUps);
    final totalReturned = session.players.fold(0, (sum, p) => sum + p.cashOut);
    final diff = totalIssued - totalReturned;
    final balanced = diff == 0;
    final isActive = session.status == 'active';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _selectedIndex = -1),
        ),
        title: Text(session.name),
        actions: [
          if (isActive)
            PNButton(label: 'Complete', onPressed: () => _completeSession(session), outlined: true),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
          const PNSectionHeader(title: 'Reconciliation'),
          PNCard(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                _ReconRow(label: 'Total Issued', amount: totalIssued, color: Colors.red.shade700),
                const SizedBox(height: 4),
                _ReconRow(label: 'Total Returned', amount: totalReturned, color: Colors.green.shade700),
                const Divider(height: 16),
                _ReconRow(label: 'Difference', amount: diff, color: balanced ? Colors.green : Colors.red, bold: true),
              ],
            ),
          ),
          if (!balanced && isActive) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Text('Totals don\'t balance!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          PNSectionHeader(
            title: 'Players',
            actionLabel: isActive ? 'Add Player' : null,
            onAction: isActive ? () => _showAddPlayerDialog(session) : null,
          ),
          Expanded(
            child: session.players.isEmpty
                ? Center(child: Text('No players yet.', style: TextStyle(color: Colors.grey.shade500)))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: session.players.length,
                    itemBuilder: (_, i) {
                      final player = session.players[i];
                      final totalIn = player.buyIn + player.topUps;
                      final profit = player.cashOut - totalIn;
                      return PNCard(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                                  child: Text(player.name[0].toUpperCase(), style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(player.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      Text('In: \$$totalIn   Out: \$${player.cashOut}',
                                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                                Text(
                                  profit >= 0 ? '+\$$profit' : '-\$${-profit}',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: profit >= 0 ? Colors.green : Colors.red),
                                ),
                              ],
                            ),
                            if (isActive) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  PNButton(label: 'Top-up', onPressed: () => _recordTopUp(session, player), outlined: true, icon: Icons.add_circle_outline),
                                  const SizedBox(width: 8),
                                  PNButton(label: 'Cash Out', onPressed: () => _recordCashOut(session, player), outlined: true, icon: Icons.money_off, destructive: true),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? AppColors.accent.withValues(alpha: 0.1) : AppColors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive ? 'Active' : 'Completed',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isActive ? AppColors.accent : AppColors.green),
      ),
    );
  }
}

class _ReconRow extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  final bool bold;

  const _ReconRow({required this.label, required this.amount, required this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        Text('\$$amount', style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: color, fontSize: bold ? 15 : 14)),
      ],
    );
  }
}
