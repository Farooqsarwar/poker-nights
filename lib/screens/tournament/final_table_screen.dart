import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_alert_banner.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/svg_countdown_ring.dart';

class _SeatEntry {
  _SeatEntry({required this.id, required this.name, required this.seat});

  final String id;
  final String name;
  int seat;
}

/// Final table redraw matching spec C7 and mockup `03_07_final_table.png`.
class FinalTableScreen extends StatefulWidget {
  const FinalTableScreen({super.key});

  @override
  State<FinalTableScreen> createState() => _FinalTableScreenState();
}

class _FinalTableScreenState extends State<FinalTableScreen> with SingleTickerProviderStateMixin {
  final _random = Random();
  List<_SeatEntry> _seating = [];
  bool _confirmed = false;

  /// Selected seat ID for inspection, dealer assignment, and tap-to-swap.
  String? _selectedId;

  /// Initial dealer-button position for the final table — picked randomly
  /// with the redraw and adjustable by the admin before confirming
  /// (Tech spec §12.3: the redraw creates the seats AND the dealer position).
  String? _dealerId;

  /// Timer for the level countdown
  Timer? _levelTimer;
  late AnimationController _levelProgressController;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppProvider>();
    final game = app.currentGame;
    if (game != null) {
      final active = game.activePlayers.toList()..shuffle(_random);
      // Final table seats at most 9 players (checklist 13-025).
      final finalists = active.length > 9 ? active.sublist(0, 9) : active;
      _seating = [
        for (var i = 0; i < finalists.length; i++)
          _SeatEntry(id: finalists[i].id, name: finalists[i].name, seat: i + 1),
      ];
      _dealerId = finalists.isEmpty
          ? null
          : finalists[_random.nextInt(finalists.length)].id;
      _selectedId = _dealerId ?? (_seating.isNotEmpty ? _seating.first.id : null);
    }

    // Initialize level progress animation
    _levelProgressController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _startLevelTimer();
  }

  @override
  void dispose() {
    _levelTimer?.cancel();
    _levelProgressController.dispose();
    super.dispose();
  }

  void _startLevelTimer() {
    _levelTimer?.cancel();
    final app = context.read<AppProvider>();
    final game = app.currentGame;
    if (game == null) return;

    final level = game.currentLevel;
    final structure = game.structure;
    if (level > structure.levels.length) return;

    final levelDuration = structure.levels[level - 1].durationMins * 60;
    _levelProgressController.duration = Duration(seconds: levelDuration);
    _levelProgressController.forward(from: 0.0);

    _levelTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  void _swapSeats(String draggedId, String targetId) {
    if (draggedId == targetId) return;
    final dragged = _seating.where((s) => s.id == draggedId).firstOrNull;
    final target = _seating.where((s) => s.id == targetId).firstOrNull;
    if (dragged == null || target == null) return;
    setState(() {
      final draggedSeat = dragged.seat;
      dragged.seat = target.seat;
      target.seat = draggedSeat;
      _selectedId = target.id;
    });
  }

  void _onSeatTapped(String seatId) {
    setState(() {
      if (_selectedId == null || _selectedId == seatId) {
        _selectedId = seatId;
      } else {
        // Tap another seat while one is selected -> swap them!
        _swapSeats(_selectedId!, seatId);
      }
    });
  }

  void _redraw() {
    setState(() {
      final arr = [..._seating]..shuffle(_random);
      for (var i = 0; i < arr.length; i++) {
        arr[i].seat = i + 1;
      }
      _seating = arr;
      // A fresh redraw picks a fresh random dealer position.
      _dealerId = arr.isEmpty ? null : arr[_random.nextInt(arr.length)].id;
      _selectedId = _dealerId ?? (_seating.isNotEmpty ? _seating.first.id : null);
    });
  }

  void _confirm(AppProvider app) {
    final seating = [for (final s in _seating) (playerId: s.id, seat: s.seat)];
    app.confirmFinalTable(seating: seating, dealerId: _dealerId);
    setState(() => _confirmed = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) context.go(RoutePaths.hostDashboard);
    });
  }

  @override
  Widget build(BuildContext context) {
    try {
      final app = context.watch<AppProvider>();

      // Spec §3.3: Only admin can run final table.
      if (!app.isAdmin) {
        return const Scaffold(
          body: Center(child: Text('Host access required.')),
        );
      }

      final game = app.currentGame;

      if (game == null) {
        // No game in provider — redirect back to dashboard instead of
        // showing a blank screen dead-end.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go(RoutePaths.hostDashboard);
        });
        return const SizedBox.shrink();
      }

      final tooMany = game.activePlayers.length > 9;
      final selectedEntry = _seating.where((s) => s.id == _selectedId).firstOrNull;

      return AppPage(
        maxWidth: 500,
        padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top row: Back button (matching 03_07_final_table.png top-left chevron box)
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              label: 'Back to dashboard',
              child: InkWell(
                onTap: () => context.go(RoutePaths.hostDashboard),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2C2C30)),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Eyebrow badge: Trophy icon + FINAL TABLE (amber pill badge per 03_07_final_table.png)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.redDim,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primarySoftBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 15,
                    color: AppColors.redText,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'FINAL TABLE',
                    style: AppTypography.eyebrow(
                      color: AppColors.redText,
                      weight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
),
            ),
            const SizedBox(height: AppSpacing.sm),

            // SVG Countdown Ring for level progress
            AnimatedBuilder(
              animation: _levelProgressController,
              builder: (context, child) {
                return Center(
                  child: SvgCountdownRing(
                    progress: _levelProgressController.value,
                    scale: 1.5,
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),

            // Title: Redraw the seats
          Text(
            'Redraw the seats',
            textAlign: TextAlign.center,
            style: AppTypography.display(
              size: AppFontSizes.xxxl,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Subtitle: 9 players remain
          Text(
            '${_seating.length} players remain',
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          if (tooMany) ...[
            const AppAlertBanner(
              type: AppAlertType.warning,
              message:
                  'More than 9 players are still in. The final table holds a maximum of 9 seats.',
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          if (_confirmed) ...[
            AppCard(
              glow: true,
              padding: const EdgeInsets.all(AppSpacing.xxxl),
              child: Column(
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    color: AppColors.primary,
                    size: AppFontSizes.displayLg,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Final Table Set!',
                    style: AppTypography.crimsonShimmer(size: AppFontSizes.xxl),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Returning to dashboard…',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Central Poker Table Ring Graphic matching 03_07_final_table.png
            Center(
              child: _PokerTableVisual(
                seating: _seating,
                selectedId: _selectedId,
                dealerId: _dealerId,
                onSeatTapped: _onSeatTapped,
                onSwap: _swapSeats,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            _FinalistLeaderboard(game: game),
            const SizedBox(height: AppSpacing.lg),
            // Active Seat Card: Player assignment & Dealer toggle
            if (selectedEntry != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${selectedEntry.seat}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedEntry.name,
                            style: AppTypography.bodySm.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.foreground,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _dealerId == selectedEntry.id
                                ? 'Dealer button (D)'
                                : 'Tap another seat to swap',
                            style: AppTypography.bodyXs.copyWith(
                              color: _dealerId == selectedEntry.id
                                  ? AppColors.redText
                                  : AppColors.mutedForeground,
                              fontWeight: _dealerId == selectedEntry.id
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _dealerId = selectedEntry.id;
                        });
                      },
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: _dealerId == selectedEntry.id
                              ? AppColors.redDim
                              : AppColors.card,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: _dealerId == selectedEntry.id
                                ? AppColors.primarySoftBorder
                                : AppColors.borderSubtle,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _dealerId == selectedEntry.id
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: 14,
                              color: _dealerId == selectedEntry.id
                                  ? AppColors.redText
                                  : AppColors.mutedForeground,
                            ),
                            const SizedBox(width: AppSpacing.xxs),
                            Text(
                              'Dealer',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _dealerId == selectedEntry.id
                                    ? AppColors.redText
                                    : AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: AppSpacing.xl),

            // Bottom CTA: Primary crimson button "Assign seats & continue"
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: tooMany ? null : () => _confirm(app),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shadowColor: AppColors.primary.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  tooMany ? 'Eliminate to 9 first' : 'Assign seats & continue',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Secondary link: "Shuffle again"
            Center(
              child: TextButton(
                onPressed: _redraw,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(120, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                ),
                child: const Text(
                  'Shuffle again',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE53935),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
    } catch (e, stack) {
      print('BUILD EXCEPTION: $e\n$stack');
      rethrow;
    }
  }
}

/// Circular poker table graphic rendering the red glowing ring with seat nodes
/// arranged radially around the circumference, precisely matching `03_07_final_table.png`.
class _PokerTableVisual extends StatelessWidget {
  const _PokerTableVisual({
    required this.seating,
    required this.selectedId,
    required this.dealerId,
    required this.onSeatTapped,
    required this.onSwap,
  });

  final List<_SeatEntry> seating;
  final String? selectedId;
  final String? dealerId;
  final ValueChanged<String> onSeatTapped;
  final void Function(String draggedId, String targetId) onSwap;

  @override
  Widget build(BuildContext context) {
    const double tableSize = 290.0;
    const double nodeSize = 44.0;
    const double ringRadius = 100.0;
    const double centerOffset = tableSize / 2;

    final sorted = [...seating]..sort((a, b) => a.seat.compareTo(b.seat));
    final count = sorted.length;

    return SizedBox(
      width: tableSize,
      height: tableSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer subtle dark glow felt background
          Container(
            width: ringRadius * 2,
            height: ringRadius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF111113),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  blurRadius: 36,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),

          // Crimson red ring boundary
          Container(
            width: ringRadius * 2,
            height: ringRadius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),

          // Center text: "Seat 1–9" (or 1–N) in crimson red
          Center(
            child: Text(
              count > 0 ? 'Seat 1–$count' : 'Final Table',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFE53935),
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),

          // Seat nodes distributed clockwise around the ring
          for (var i = 0; i < count; i++) ...[
            Builder(
              builder: (context) {
                final s = sorted[i];
                // Start from top (12 o'clock = -pi/2), then distribute clockwise
                final angle = -pi / 2 + (2 * pi * i / count);
                final x = centerOffset + ringRadius * cos(angle) - (nodeSize / 2);
                final y = centerOffset + ringRadius * sin(angle) - (nodeSize / 2);

                final isSelected = s.id == selectedId;
                final isDealer = s.id == dealerId;
                // Highlight if selected or dealer (e.g. seat 1 and 7 in mockup)
                final isHighlighted = isSelected || isDealer;

                return Positioned(
                  left: x,
                  top: y,
                  width: nodeSize,
                  height: nodeSize,
                  child: _RadialSeatNode(
                    entry: s,
                    nodeSize: nodeSize,
                    isHighlighted: isHighlighted,
                    isDealer: isDealer,
                    onTap: () => onSeatTapped(s.id),
                    onSwap: onSwap,
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _RadialSeatNode extends StatelessWidget {
  const _RadialSeatNode({
    required this.entry,
    required this.nodeSize,
    required this.isHighlighted,
    required this.isDealer,
    required this.onTap,
    required this.onSwap,
  });

  final _SeatEntry entry;
  final double nodeSize;
  final bool isHighlighted;
  final bool isDealer;
  final VoidCallback onTap;
  final void Function(String draggedId, String targetId) onSwap;

  Widget _nodeCircle({bool dimmed = false, bool isHovering = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: nodeSize,
      height: nodeSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isHovering
            ? AppColors.primarySoft
            : isHighlighted
                ? const Color(0xFFE53935)
                : const Color(0xFF222226),
        border: Border.all(
          color: isHovering
              ? AppColors.primary
              : isHighlighted
                  ? const Color(0xFFFF5252)
                  : const Color(0xFF35353A),
          width: isHighlighted || isHovering ? 2.0 : 1.2,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: const Color(0xFFE53935).withValues(alpha: 0.6),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          '${entry.seat}',
          style: TextStyle(
            color: Colors.white,
            fontWeight: isHighlighted ? FontWeight.w800 : FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Draggable<_SeatEntry>(
      data: entry,
      feedback: Material(
        color: Colors.transparent,
        child: _nodeCircle(),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _nodeCircle(dimmed: true),
      ),
      child: DragTarget<_SeatEntry>(
        onWillAcceptWithDetails: (details) => details.data.id != entry.id,
        onAcceptWithDetails: (details) => onSwap(details.data.id, entry.id),
        builder: (context, candidates, rejected) {
          final isHovering = candidates.isNotEmpty;
          return Semantics(
            button: true,
            label: 'Seat ${entry.seat}: ${entry.name}${isDealer ? ', Dealer' : ''}',
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: _nodeCircle(isHovering: isHovering),
            ),
          );
        },
      ),
    );
  }
}


class _FinalistLeaderboard extends StatelessWidget {
  const _FinalistLeaderboard({required this.game});

  final dynamic game; // LiveGame or Game

  @override
  Widget build(BuildContext context) {
    try {
      final active = List<dynamic>.from(game.activePlayers);
      active.sort((dynamic a, dynamic b) => (b.stack ?? 0).compareTo(a.stack ?? 0) as int);
      final int rawBb = (game.structure.levels.isNotEmpty && game.currentLevel > 0 && game.currentLevel <= game.structure.levels.length)
          ? game.structure.levels[game.currentLevel - 1].bb
          : (game.structure.levels.isNotEmpty ? game.structure.levels.first.bb : 100);
      final bb = rawBb > 0 ? rawBb : 100;

      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'CHIP LEADERBOARD',
            style: AppTypography.monoXs.copyWith(
              color: AppColors.mutedForeground,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < active.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${i + 1}',
                      style: AppTypography.monoSm.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      active[i].name,
                      style: AppTypography.bodySm.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${(active[i].stack ?? 0)}',
                    style: AppTypography.monoSm,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${((active[i].stack ?? 0) / bb).toStringAsFixed(1)} BB',
                      textAlign: TextAlign.right,
                      style: AppTypography.monoXs.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    } catch (e, stack) {
      print('LEADERBOARD EXCEPTION: $e\n$stack');
      rethrow;
    }
  }
}
