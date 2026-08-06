import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../../models/chip_color.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/chip_token.dart';

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
        backgroundColor: AppColors.card,
        title: const Text('Delete chip set?'),
        content: Text(
          '"${cs.name}" will be removed. Games already played with it stay in history unchanged.',
          style: AppTypography.bodySm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: AppTypography.bodySm.copyWith(color: AppColors.destructive),
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
      maxWidth: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(RoutePaths.settings),
              ),
              Expanded(
                child: Text('Chip Sets', style: AppTypography.display(size: AppFontSizes.xxl, weight: FontWeight.w700)),
              ),
              AppButton(
                onPressed: () => context.push(RoutePaths.editChipSet),
                child: const Text('New Chip Set'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (chipSets.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text('No saved chip sets.', style: AppTypography.bodyLg.copyWith(color: AppColors.mutedForeground)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: chipSets.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final cs = chipSets[index];
                return AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cs.name, style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: AppSpacing.xs),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: cs.chips.map((c) => ChipToken(
                                colorName: c.color,
                                hex: c.colorValue,
                                value: c.value,
                                count: c.quantity,
                              )).toList(),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: AppColors.mutedForeground),
                        onPressed: () => context.push(RoutePaths.editChipSet, extra: cs.id),
                      ),
                      if (cs.id != 'cs-default')
                        IconButton(
                          icon: const Icon(Icons.delete, color: AppColors.destructive),
                          onPressed: () => _confirmDelete(context, app, cs),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
