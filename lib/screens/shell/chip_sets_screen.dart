import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../../models/chip_color.dart';
import '../../widgets/app_page.dart';
import '../../widgets/back_nav_button.dart';
import '../../widgets/squircle_icon_button.dart';

/// Chip sets screen matching mobile-first design.
class ChipSetsScreen extends StatelessWidget {
  const ChipSetsScreen({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    AppProvider app,
    ({String id, String name, List<ChipColor> chips}) cs,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121417),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF22262B)),
        ),
        title: const Text(
          'Delete chip set?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '"${cs.name}" will be removed. Games already played with it stay in history unchanged.',
          style: AppTypography.bodySm.copyWith(color: const Color(0xFF8E8E93)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.bodySm.copyWith(
                color: const Color(0xFF8E8E93),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok == true) app.deleteChipSet(cs.id);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final chipSets = app.savedChipSets;

    return AppPage(
      maxWidth: 560,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Squircle Back button & New button
          Row(
            children: [
              BackNavButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(RoutePaths.settings);
                  }
                },
                label: 'Back to settings',
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Chip sets',
                  style: AppTypography.display(
                    size: 28,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              InkWell(
                onTap: () => context.push(RoutePaths.editChipSet),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD53032),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x55D53032),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    '+ New',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (chipSets.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  children: [
                    const Icon(
                      Icons.casino_outlined,
                      size: 48,
                      color: Color(0xFF71767B),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No saved chip sets.',
                      style: AppTypography.bodyLg.copyWith(
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: chipSets.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final cs = chipSets[index];
                final isDefault =
                    cs.id == (app.defaultChipSetId ?? 'cs-default');
                final totalChips = cs.chips.fold(
                  0,
                  (sum, c) => sum + c.quantity,
                );

                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121417),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF22262B)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Chip set title & actions row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    cs.name,
                                    style: AppTypography.body(
                                      size: 18,
                                      weight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isDefault) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF132A1C),
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.pill,
                                      ),
                                      border: Border.all(
                                        color: const Color(0x4422C55E),
                                      ),
                                    ),
                                    child: const Text(
                                      'DEFAULT',
                                      style: TextStyle(
                                        color: Color(0xFF4ADE80),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          SquircleIconButton(
                            icon: Icons.edit_outlined,
                            size: 36,
                            iconSize: 18,
                            iconColor: const Color(0xFF8E8E93),
                            tooltip: 'Edit ${cs.name}',
                            onPressed: () => context.push(
                              RoutePaths.editChipSet,
                              extra: cs.id,
                            ),
                          ),
                          if (cs.id != 'cs-default') ...[
                            const SizedBox(width: 8),
                            SquircleIconButton(
                              icon: Icons.delete_outline,
                              size: 36,
                              iconSize: 18,
                              iconColor: const Color(0xFFEF4444),
                              tooltip: 'Delete ${cs.name}',
                              onPressed: () => _confirmDelete(context, app, cs),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${cs.chips.length} denominations · $totalChips total chips',
                        style: AppTypography.bodyXs.copyWith(
                          color: const Color(0xFF8E8E93),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Visual chip tokens display
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: cs.chips.map((c) {
                          return _buildVisualChipToken(c);
                        }).toList(),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static Widget _buildVisualChipToken(ChipColor c) {
    final chipColor = c.colorValue;
    final valueText = c.value >= 1000
        ? '${(c.value / 1000).toStringAsFixed(c.value % 1000 == 0 ? 0 : 1)}K'
        : '${c.value}';

    // Decide contrasting text color for chip center
    final luminance = chipColor.computeLuminance();
    final textColor = luminance > 0.6 ? Colors.black87 : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF191D22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262B31)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Visual Poker Chip Token Disc
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: chipColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x44000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                valueText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                c.color,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                '×${c.quantity}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8E8E93),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
