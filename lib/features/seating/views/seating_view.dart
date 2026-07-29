import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/core/theme/app_colors.dart';
import 'package:poker_night/core/widgets/pn_button.dart';
import 'package:poker_night/core/widgets/pn_card.dart';
import 'package:poker_night/features/auth/controllers/auth_controller.dart';
import 'package:poker_night/features/live_game/controllers/live_game_controller.dart';
import 'package:poker_night/features/live_game/models/game_state_model.dart';
import 'package:poker_night/features/seating/models/table_model.dart';
import 'package:poker_night/services/storage_service.dart';
import 'package:poker_night/services/voice_service.dart';

class SeatingView extends StatefulWidget {
  final String tournamentId;

  const SeatingView({super.key, required this.tournamentId});

  @override
  State<SeatingView> createState() => _SeatingViewState();
}

class _SeatingViewState extends State<SeatingView> {
  final _tables = <TableModel>[];

  @override
  void initState() {
    super.initState();
  }

  void _generateSeatingFromPlayers() {
    final controller = Get.find<LiveGameController>(tag: widget.tournamentId);
    final gameState = controller.state;
    final activePlayers = gameState.players.where((p) => p.status == 'active').toList();
    if (activePlayers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active players to seat')),
      );
      return;
    }

    final shuffled = List<PlayerState>.from(activePlayers)..shuffle(math.Random());
    final tables = <TableModel>[];
    const seatsPerTable = 9;
    var playerIdx = 0;
    var tableNumber = 1;

    while (playerIdx < shuffled.length) {
      final remaining = shuffled.length - playerIdx;
      final seatsInTable = math.min(remaining, seatsPerTable);
      final seatList = List.generate(seatsPerTable, (i) {
        if (i < seatsInTable) {
          final player = shuffled[playerIdx++];
          return SeatModel(seatNumber: i + 1, isOccupied: true, playerName: player.name);
        }
        return SeatModel(seatNumber: i + 1, isOccupied: false);
      });

      tables.add(TableModel(id: 'table_$tableNumber', tableNumber: tableNumber, seats: seatList));
      tableNumber++;
    }

    // Update game state with table assignments
    final updatedPlayers = gameState.players.map((p) {
      for (final table in tables) {
        for (final seat in table.seats) {
          if (seat.playerName == p.name) {
            return p.copyWith(tableNo: table.tableNumber, seatNo: seat.seatNumber);
          }
        }
      }
      return p;
    }).toList();
    controller.setPlayers(updatedPlayers);

    setState(() => _tables.addAll(tables));
  }

  void _showManualAssignmentDialog(TableModel table, int seatIndex) {
    final controller = Get.find<LiveGameController>(tag: widget.tournamentId);
    final gameState = controller.state;
    final unseated = gameState.players.where((p) =>
      p.status == 'active' &&
      !_tables.any((t) => t.seats.any((s) => s.playerName == p.name))
    ).toList();

    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign Player'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (unseated.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                initialValue: null,
                decoration: const InputDecoration(labelText: 'Select Player'),
                items: unseated.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                onChanged: (v) {
                  final player = unseated.where((p) => p.id == v).firstOrNull;
                  if (player != null) {
                    nameController.text = player.name;
                  }
                },
              ),
              const SizedBox(height: 12),
              const Text('Or type a name:'),
            ],
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Player Name', hintText: 'Enter player name'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          PNButton(
            label: 'Clear',
            outlined: true,
            onPressed: () {
              final tIdx = _tables.indexOf(table);
              if (tIdx != -1) {
                final updatedSeats = _tables[tIdx].seats.map((seat) {
                  final sIdx = _tables[tIdx].seats.indexOf(seat);
                  if (sIdx == seatIndex) {
                    return seat.copyWith(isOccupied: false, playerName: null);
                  }
                  return seat;
                }).toList();
                setState(() {
                  _tables[tIdx] = _tables[tIdx].copyWith(seats: updatedSeats);
                });
              }
              Navigator.of(ctx).pop();
            },
          ),
          PNButton(
            label: 'Assign',
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final tIdx = _tables.indexOf(table);
                if (tIdx != -1) {
                  final updatedSeats = _tables[tIdx].seats.map((seat) {
                    final sIdx = _tables[tIdx].seats.indexOf(seat);
                    if (sIdx == seatIndex) {
                      return seat.copyWith(isOccupied: true, playerName: name);
                    }
                    return seat;
                  }).toList();
                  setState(() {
                    _tables[tIdx] = _tables[tIdx].copyWith(seats: updatedSeats);
                  });
                }
                Navigator.of(ctx).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  void _redrawFinalTable() {
    final players = <String>[];
    for (final table in _tables) {
      for (final seat in table.seats) {
        if (seat.isOccupied && seat.playerName != null) {
          players.add(seat.playerName!);
        }
      }
    }

    if (players.length != 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need exactly 9 active players for the final table.')),
      );
      return;
    }

    final shuffled = List<String>.from(players)..shuffle(math.Random());
    final finalSeats = List.generate(9, (i) {
      return SeatModel(seatNumber: i + 1, isOccupied: true, playerName: shuffled[i]);
    });

    setState(() {
      _tables.clear();
      _tables.add(TableModel(id: 'final_table', tableNumber: 1, seats: finalSeats, isFinalTable: true));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authController = Get.find<AuthController>();
    final controller = Get.isRegistered<LiveGameController>(tag: widget.tournamentId)
        ? Get.find<LiveGameController>(tag: widget.tournamentId)
        : Get.put(LiveGameController(Get.find<StorageService>(), Get.find<VoiceService>(), widget.tournamentId), tag: widget.tournamentId);

    return Obx(() {
      final isAdmin = authController.isAuthenticated;
      final gameState = controller.state;
      final activeCount = gameState.players.where((p) => p.status == 'active').length;

      return Scaffold(
      appBar: AppBar(
        title: const Text('Seating'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        actions: [
          if (isAdmin) ...[
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'random':
                    _generateSeatingFromPlayers();
                    break;
                  case 'final':
                    _redrawFinalTable();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'random', child: ListTile(leading: Icon(Icons.shuffle), title: Text('Auto Seat Players'))),
                if (_tables.isNotEmpty)
                  const PopupMenuItem(value: 'final', child: ListTile(leading: Icon(Icons.emoji_events), title: Text('Final Table Redraw'))),
              ],
            ),
          ],
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: _tables.isEmpty
              ? _buildEmptyState(theme, isAdmin, activeCount)
              : _buildSeatingLayout(theme, isAdmin),
        ),
      ),
      );
    });
  }

  Widget _buildEmptyState(ThemeData theme, bool isAdmin, int activeCount) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.table_restaurant_outlined, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('No tables set up', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 8),
            Text('$activeCount active player${activeCount == 1 ? '' : 's'} available to seat.', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
            if (isAdmin && activeCount > 0) ...[
              const SizedBox(height: 24),
              PNButton(
                onPressed: _generateSeatingFromPlayers,
                icon: Icons.shuffle,
                label: 'Auto-Seat $activeCount Players',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSeatingLayout(ThemeData theme, bool isAdmin) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tables.length,
      itemBuilder: (context, index) => _buildTableCard(_tables[index], theme, isAdmin),
    );
  }

  Widget _buildTableCard(TableModel table, ThemeData theme, bool isAdmin) {
    final occupied = table.seats.where((s) => s.isOccupied).length;
    final total = table.seats.length;
    final width = MediaQuery.of(context).size.width;

    return PNCard(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                if (table.isFinalTable) Icon(Icons.emoji_events, color: Colors.amber.shade700),
                if (table.isFinalTable) const SizedBox(width: 8),
                Text(table.isFinalTable ? 'Final Table' : 'Table ${table.tableNumber}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('$occupied/$total players', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              ],
            ),
            const SizedBox(height: 16),
            CustomPaint(
              size: Size(width - 64, (width - 64) * 0.65),
              painter: _TablePainter(table: table),
            ),
            const SizedBox(height: 8),
            _buildSeatLabels(table, theme, isAdmin),
          ],
        ),
      ),
    );
  }

  Widget _buildSeatLabels(TableModel table, ThemeData theme, bool isAdmin) {
    final totalSeats = table.seats.length;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: totalSeats > 6 ? 3 : 2,
        childAspectRatio: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: totalSeats,
      itemBuilder: (context, index) {
        final seat = table.seats[index];
        return InkWell(
          onTap: isAdmin ? () => _showManualAssignmentDialog(table, index) : null,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: seat.isOccupied ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: seat.isOccupied ? AppColors.primary.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(seat.isOccupied ? Icons.person : Icons.person_outline, size: 14, color: seat.isOccupied ? AppColors.primary : Colors.grey),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    seat.playerName ?? 'Seat ${seat.seatNumber}',
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: seat.isOccupied ? AppColors.primary : Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TablePainter extends CustomPainter {
  final TableModel table;
  _TablePainter({required this.table});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF1B5E20)..style = PaintingStyle.fill;
    final borderPaint = Paint()..color = const Color(0xFF2E7D32)..style = PaintingStyle.stroke..strokeWidth = 3;
    final rect = Rect.fromLTWH(size.width * 0.1, size.height * 0.1, size.width * 0.8, size.height * 0.8);
    canvas.drawOval(rect, paint);
    canvas.drawOval(rect, borderPaint);

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final rx = size.width * 0.4;
    final ry = size.height * 0.4;

    for (var i = 0; i < table.seats.length; i++) {
      final angle = (2 * math.pi * i / table.seats.length) - math.pi / 2;
      final seatX = centerX + rx * math.cos(angle);
      final seatY = centerY + ry * math.sin(angle);

      final seatPaint = Paint()
        ..color = table.seats[i].isOccupied ? Colors.orange : Colors.grey.shade400
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(seatX, seatY), 14, seatPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: table.seats[i].isOccupied
              ? (table.seats[i].playerName?.substring(0, 1).toUpperCase() ?? '?')
              : '${table.seats[i].seatNumber}',
          style: TextStyle(
            color: Colors.white,
            fontSize: table.seats[i].isOccupied ? 13 : 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(seatX - textPainter.width / 2, seatY - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _TablePainter oldDelegate) => oldDelegate.table != table;
}
