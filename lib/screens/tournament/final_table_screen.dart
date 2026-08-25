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
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon_label.dart';
import '../../widgets/app_page.dart';

class _SeatEntry {
  _SeatEntry({required this.id, required this.name, required this.seat});

  final String id;
  final String name;
  int seat;
}

/// Final table redraw mirroring the web `FinalTablePage`.
class FinalTableScreen extends StatefulWidget {
  const FinalTableScreen({super.key});

  @override
  State<FinalTableScreen> createState() => _FinalTableScreenState();
}

class _FinalTableScreenState extends State<FinalTableScreen> {
  final _random = Random();
  List<_SeatEntry> _seating = [];
  bool _confirmed = false;

  /// Initial dealer-button position for the final table — picked randomly
  /// with the redraw and adjustable by the admin before confirming
  /// (Tech spec §12.3: the redraw creates the seats AND the dealer position).
  String? _dealerId;

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
    }
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
    });
  }

  void _confirm(AppProvider app) {
    final seating = [for (final s in _seating) (playerId: s.id, seat: s.seat)];
    app.confirmFinalTable(seating: seating, dealerId: _dealerId);
    setState(() => _confirmed = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) context.go(RoutePaths.adminDashboard);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final game = app.currentGame;

    if (game == null) {
      // No game in provider — redirect back to dashboard instead of
      // showing a blank screen dead-end.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(RoutePaths.adminDashboard);
      });
      return const SizedBox.shrink();
    }

    final tooMany = game.activePlayers.length > 9;

    return AppPage(
      maxWidth: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => context.go(RoutePaths.adminDashboard),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xs),
                  child: Icon(
                    Icons.arrow_back,
                    color: AppColors.mutedForeground,
                    size: AppFontSizes.xl,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Final Table Redraw',
                    style: AppTypography.display(
                      size: AppFontSizes.xxxl,
                      weight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${_seating.length} players · random seating',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppAlertBanner(
            type: AppAlertType.info,
            message:
                'All remaining players draw new seats at the final table. This cannot be undone.',
          ),
          if (tooMany) ...[
            const SizedBox(height: AppSpacing.md),
            const AppAlertBanner(
              type: AppAlertType.warning,
              message:
                  'More than 9 players are still in. The final table holds a maximum of 9 seats.',
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (_confirmed)
            AppCard(
              glow: true,
              padding: const EdgeInsets.all(AppSpacing.xxxl),
              child: Column(
                children: [
                  Icon(
                    Icons.casino,
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
            )
          else ...[
            // Seating visual
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  Text(
                    'Final Table Seating',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Drag a seat onto another to swap them.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: AppSpacing.sm,
                          crossAxisSpacing: AppSpacing.sm,
                          childAspectRatio: 1.6,
                        ),
                    itemCount: _seating.length,
                    itemBuilder: (context, i) {
                      final s = _seating[i];
                      return _DraggableSeatTile(entry: s, onSwap: _swapSeats);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Initial dealer position (Tech spec §12.3: the redraw also picks
            // the dealer-button position; the admin can adjust it).
            // Shown as a list — no graphical poker table (User Flow §4.15).
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Initial dealer position',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Picked randomly with the redraw — tap to change.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final s in [
                        ..._seating,
                      ]..sort((a, b) => a.seat.compareTo(b.seat)))
                        InkWell(
                          onTap: () => setState(() => _dealerId = s.id),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: _dealerId == s.id
                                  ? AppColors.primarySoft
                                  : AppColors.secondary,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: _dealerId == s.id
                                    ? AppColors.primary
                                    : AppColors.border,
                                width: _dealerId == s.id ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_dealerId == s.id) ...[
                                  Icon(
                                    Icons.style,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  'Seat ${s.seat} · ${s.name}',
                                  style: AppTypography.bodyXs.copyWith(
                                    color: _dealerId == s.id
                                        ? AppColors.primary
                                        : AppColors.mutedForeground,
                                    fontWeight: _dealerId == s.id
                                        ? FontWeight.w700
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    variant: AppButtonVariant.secondary,
                    onPressed: _redraw,
                    child: const AppIconLabel(
                      label: 'Redraw',
                      icon: Icons.refresh,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    disabled: tooMany,
                    onPressed: () => _confirm(app),
                    child: AppIconLabel(
                      label: tooMany
                          ? 'Eliminate to 9 first'
                          : 'Confirm seating',
                      icon: tooMany ? null : Icons.event_seat,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _DraggableSeatTile extends StatefulWidget {
  const _DraggableSeatTile({required this.entry, required this.onSwap});

  final _SeatEntry entry;
  final void Function(String draggedId, String targetId) onSwap;

  @override
  State<_DraggableSeatTile> createState() => _DraggableSeatTileState();
}

class _DraggableSeatTileState extends State<_DraggableSeatTile> {
  Widget _tile({bool dimmed = false, Color? borderColor, Color? background}) {
    final s = widget.entry;
    return Opacity(
      opacity: dimmed ? 0.35 : 1,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: background ?? AppColors.secondary,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: borderColor ?? AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Seat ${s.seat}',
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              s.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.entry;
    return Draggable<_SeatEntry>(
      data: s,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.primary, width: 2),
            boxShadow: AppShadows.cardGlowActive,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Seat ${s.seat}',
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                s.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySm.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: _tile(dimmed: true),
      child: DragTarget<_SeatEntry>(
        onWillAcceptWithDetails: (details) => details.data.id != s.id,
        onAcceptWithDetails: (details) => widget.onSwap(details.data.id, s.id),
        builder: (context, candidates, rejected) {
          final hovering = candidates.isNotEmpty;
          return _tile(
            borderColor: hovering ? AppColors.primary : AppColors.border,
            background: hovering ? AppColors.primarySoft : AppColors.secondary,
          );
        },
      ),
    );
  }
}
