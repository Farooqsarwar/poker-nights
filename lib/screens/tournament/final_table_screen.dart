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

  @override
  void initState() {
    super.initState();
    final app = context.read<AppProvider>();
    final game = app.currentGame;
    if (game != null) {
      final active = game.activePlayers.toList()..shuffle(_random);
      _seating = [
        for (var i = 0; i < active.length; i++)
          _SeatEntry(id: active[i].id, name: active[i].name, seat: i + 1),
      ];
    }
  }

  void _redraw() {
    setState(() {
      final arr = [..._seating]..shuffle(_random);
      for (var i = 0; i < arr.length; i++) {
        arr[i].seat = i + 1;
      }
      _seating = arr;
    });
  }

  void _confirm(AppProvider app) {
    final seating = [
      for (final s in _seating) (playerId: s.id, seat: s.seat),
    ];
    app.confirmFinalTable(seating: seating);
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
      return const SizedBox.shrink();
    }

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
                child: const Padding(
                  padding: EdgeInsets.all(AppSpacing.xs),
                  child: Text('←', style: TextStyle(color: AppColors.mutedForeground, fontSize: AppFontSizes.xl)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Final Table Redraw', style: AppTypography.display(size: AppFontSizes.xxxl, weight: FontWeight.w700)),
                  Text(
                    '${_seating.length} players · random seating',
                    style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppAlertBanner(
            type: AppAlertType.info,
            message: 'All remaining players draw new seats at the final table. This cannot be undone.',
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_confirmed)
            AppCard(
              glow: true,
              padding: const EdgeInsets.all(AppSpacing.xxxl),
              child: Column(
                children: [
                  const Text('♠', style: TextStyle(fontSize: AppFontSizes.displayLg)),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Final Table Set!',
                    style: AppTypography.crimsonShimmer(size: AppFontSizes.xxl),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Returning to dashboard…',
                    style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
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
                    style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 1.6,
                    ),
                    itemCount: _seating.length,
                    itemBuilder: (context, i) {
                      final s = _seating[i];
                      return Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.muted,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Seat ${s.seat}', style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
                            const SizedBox(height: 2),
                            Text(
                              s.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Table diagram
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  Text(
                    'Table layout',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _TableDiagram(seating: _seating),
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
                    child: const Text('↻ Redraw'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    onPressed: () => _confirm(app),
                    child: const Text('♠ Confirm seating'),
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

class _TableDiagram extends StatelessWidget {
  const _TableDiagram({required this.seating});

  final List<_SeatEntry> seating;

  @override
  Widget build(BuildContext context) {
    const width = 280.0;
    const height = 180.0;
    const cx = 140.0;
    const cy = 90.0;
    const rx = 115.0;
    const ry = 70.0;

    final sorted = [...seating]..sort((a, b) => a.seat.compareTo(b.seat));

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          // Felt table oval
          Positioned.fill(
            child: Center(
              child: Container(
                width: width - 32,
                height: height - 32,
                decoration: BoxDecoration(
                  color: AppColors.blackGlow,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  'FINAL TABLE',
                  style: AppTypography.monoXs.copyWith(color: AppColors.primary.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ),
          // Seats around the oval
          for (var i = 0; i < sorted.length; i++)
            Builder(builder: (context) {
              final angle = (i / sorted.length) * 2 * pi - pi / 2;
              final x = cx + rx * cos(angle) - 24;
              final y = cy + ry * sin(angle) - 16;
              final s = sorted[i];
              return Positioned(
                left: x,
                top: y,
                width: 48,
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${s.seat}',
                        style: AppTypography.bodyXs.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.name.split(' ').first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
