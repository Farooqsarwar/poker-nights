import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../models/game.dart';
import '../providers/app_provider.dart';
import 'app_badge.dart';
import 'app_card.dart';

/// Visual representation of a poker table and its seated players,
/// supporting drag-and-drop and tap-to-swap seat assignments (spec T4).
class PokerTableSeatingCard extends StatefulWidget {
  const PokerTableSeatingCard({
    super.key,
    required this.table,
    required this.players,
    this.maxSeats = 9,
    this.onSelectedSeatChanged,
  });

  final int table;
  final List<Player> players;
  final int maxSeats;
  final ValueChanged<String?>? onSelectedSeatChanged;

  @override
  State<PokerTableSeatingCard> createState() => _PokerTableSeatingCardState();
}

class _PokerTableSeatingCardState extends State<PokerTableSeatingCard> {
  String? _selectedPlayerId;

  void _handleSeatTap(AppProvider app, Player? seatPlayer, int seatNumber) {
    if (!app.canRunCurrentGame) return;

    if (_selectedPlayerId == null) {
      if (seatPlayer != null) {
        setState(() => _selectedPlayerId = seatPlayer.id);
        widget.onSelectedSeatChanged?.call(seatPlayer.id);
      }
    } else {
      if (seatPlayer != null) {
        if (seatPlayer.id != _selectedPlayerId) {
          app.swapPlayerSeats(_selectedPlayerId!, seatPlayer.id);
        }
      } else {
        app.movePlayerToTableAndSeat(_selectedPlayerId!, widget.table, seatNumber);
      }
      setState(() => _selectedPlayerId = null);
      widget.onSelectedSeatChanged?.call(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final game = app.currentGame;
    final dealerPlayerId = game?.dealerPlayerId;

    final occupiedSeats = widget.players.map((p) => p.seat).toList();
    final maxSeatNumber = occupiedSeats.isEmpty
        ? widget.maxSeats
        : max(widget.maxSeats, occupiedSeats.reduce(max));
    final totalSeats = max(6, min(10, maxSeatNumber));

    final seatMap = <int, Player>{};
    for (final p in widget.players) {
      seatMap[p.seat] = p;
    }

    return DragTarget<Player>(
      onWillAcceptWithDetails: (details) =>
          details.data.table != widget.table || details.data.seat != 0,
      onAcceptWithDetails: (details) {
        app.movePlayerToTableAndSeat(details.data.id, widget.table);
      },
      builder: (context, candidateData, rejectedData) {
        final isTableHovered = candidateData.isNotEmpty;

        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          borderColor: isTableHovered
              ? AppColors.primary
              : (_selectedPlayerId != null
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : null),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Table ${widget.table}',
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  AppBadge(
                    label: '${widget.players.length} players',
                    variant: AppBadgeVariant.accent,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Drag or tap players to move or swap seats',
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Visual poker table felt with radial seats
              Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth.clamp(280.0, 480.0);
                    final height = (width * 0.72).clamp(240.0, 360.0);

                    final seatWidth = 72.0;
                    final seatHeight = 48.0;
                    final radiusX = (width - seatWidth) / 2 - 4;
                    final radiusY = (height - seatHeight) / 2 - 4;
                    final centerX = width / 2;
                    final centerY = height / 2;

                    return SizedBox(
                      width: width,
                      height: height,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: width - 50,
                            height: height - 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFF141915),
                              borderRadius: BorderRadius.all(
                                Radius.elliptical(
                                  (width - 50) / 2,
                                  (height - 50) / 2,
                                ),
                              ),
                              border: Border.all(
                                color: isTableHovered
                                    ? AppColors.primary
                                    : const Color(0xFF283629),
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                          ),

                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Table ${widget.table}',
                                style: TextStyle(
                                  color: AppColors.mutedForeground,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.players.length} seated',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),

                          for (var i = 0; i < totalSeats; i++) ...[
                            Builder(
                              builder: (context) {
                                final seatNum = i + 1;
                                final player = seatMap[seatNum];
                                final isSelected =
                                    player != null && player.id == _selectedPlayerId;
                                final isDealer =
                                    player != null && player.id == dealerPlayerId;

                                final angle = -pi / 2 + (2 * pi * i / totalSeats);
                                final left =
                                    centerX + radiusX * cos(angle) - (seatWidth / 2);
                                final top =
                                    centerY + radiusY * sin(angle) - (seatHeight / 2);

                                return Positioned(
                                  left: left,
                                  top: top,
                                  width: seatWidth,
                                  height: seatHeight,
                                  child: _TableSeatNode(
                                    seatNumber: seatNum,
                                    player: player,
                                    isSelected: isSelected,
                                    isDealer: isDealer,
                                    onTap: () => _handleSeatTap(app, player, seatNum),
                                    onDroppedPlayer: (draggedPlayer) {
                                      if (player != null) {
                                        if (player.id != draggedPlayer.id) {
                                          app.swapPlayerSeats(draggedPlayer.id, player.id);
                                        }
                                      } else {
                                        app.movePlayerToTableAndSeat(
                                          draggedPlayer.id,
                                          widget.table,
                                          seatNum,
                                        );
                                      }
                                    },
                                  ),
                                );
                              },
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
        );
      },
    );
  }
}

class _TableSeatNode extends StatelessWidget {
  const _TableSeatNode({
    required this.seatNumber,
    required this.player,
    required this.isSelected,
    required this.isDealer,
    required this.onTap,
    required this.onDroppedPlayer,
  });

  final int seatNumber;
  final Player? player;
  final bool isSelected;
  final bool isDealer;
  final VoidCallback onTap;
  final ValueChanged<Player> onDroppedPlayer;

  @override
  Widget build(BuildContext context) {
    return DragTarget<Player>(
      onWillAcceptWithDetails: (details) => details.data.id != player?.id,
      onAcceptWithDetails: (details) => onDroppedPlayer(details.data),
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        Widget content = Container(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primarySoft
                : (isHovered
                    ? AppColors.primarySoft
                    : (player != null
                        ? AppColors.secondary
                        : AppColors.background.withValues(alpha: 0.6))),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isSelected || isHovered
                  ? AppColors.primary
                  : (isDealer
                      ? AppColors.primary
                      : AppColors.border),
              width: (isSelected || isHovered) ? 2.0 : 1.0,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'S$seatNumber',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDealer ? AppColors.primary : AppColors.mutedForeground,
                    ),
                  ),
                  if (isDealer) ...[
                    const SizedBox(width: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Text(
                        'D',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 1),
              Text(
                player?.name ?? 'Empty',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: player != null ? FontWeight.w600 : FontWeight.w400,
                  color: player != null
                      ? AppColors.foreground
                      : AppColors.mutedForeground.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        );

        if (player != null) {
          content = Draggable<Player>(
            data: player!,
            feedback: Material(
              color: Colors.transparent,
              child: Container(
                width: 80,
                height: 50,
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.primary, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      player!.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Seat ${player!.seat}',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: content,
            ),
            child: content,
          );
        }

        return Semantics(
          button: true,
          label: player != null
              ? 'Seat $seatNumber: ${player!.name}'
              : 'Seat $seatNumber: Empty',
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: content,
          ),
        );
      },
    );
  }
}
