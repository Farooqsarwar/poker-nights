import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/live_game.dart';
import '../../providers/app_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_alert_banner.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_select.dart';
import '../../widgets/structure_editor.dart';

/// Structure review mirroring the web `StructureReviewPage`.
class StructureReviewScreen extends StatelessWidget {
  const StructureReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final game = app.currentGame;

    if (game == null) {
      return AppEmptyState(
        title: 'No structure generated',
        description: 'Create a tournament to generate its structure.',
        action: AppButton(
          onPressed: () => context.go(RoutePaths.createTournament),
          child: const Text('Go back'),
        ),
      );
    }

    final structure = game.structure;
    final settings = game.settings;
    final totalMins = structure.levels.length * structure.levelDuration;
    final anteStartLevel = structure.levels.indexWhere((l) => l.ante != null) + 1;

    return AppPage(
      maxWidth: 640,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => context.go(RoutePaths.createTournament),
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
                  Text('Structure Review', style: AppTypography.display(size: AppFontSizes.xxxl, weight: FontWeight.w700)),
                  Text(settings.name, style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final w in structure.warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppAlertBanner(type: AppAlertType.warning, message: w),
            ),
          // Summary cards
          Row(
            children: [
              Expanded(child: _SummaryCard(label: 'Starting stack', value: Formatters.chips(structure.startingStack))),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _SummaryCard(label: 'Level duration', value: '${structure.levelDuration}m')),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _SummaryCard(label: 'Levels', value: '${structure.levels.length}')),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _SummaryCard(label: 'Est. finish', value: Formatters.duration(totalMins))),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Starting chip plan
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Starting stack — ${Formatters.chips(structure.startingStack)}',
                  style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final c in structure.chipPlan)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        _ChipDot(hex: c.hex, value: c.value),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: Text(c.color, style: AppTypography.bodySm)),
                        Text('×${c.count}', style: AppTypography.monoSm.copyWith(color: AppColors.mutedForeground)),
                        const SizedBox(width: AppSpacing.lg),
                        SizedBox(
                          width: 72,
                          child: Text(
                            Formatters.chips(c.total),
                            textAlign: TextAlign.right,
                            style: AppTypography.monoSm.copyWith(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (settings.rebuys) ...[
                  Container(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rebuy stack — ${Formatters.chips(structure.rebuyStack)}',
                          style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final c in structure.rebuyChipPlan)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                _ChipDot(hex: c.hex, value: c.value),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(child: Text(c.color, style: AppTypography.bodyXs)),
                                Text('×${c.count}', style: AppTypography.monoXs),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (settings.addOn)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      'Add-on stack: ${Formatters.chips(structure.addOnStack)} — same as starting stack',
                      style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Blind schedule
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Blind schedule — ${structure.levelDuration}-minute levels',
                      style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
                    ),
                    AppButton(
                      size: AppButtonSize.sm,
                      variant: AppButtonVariant.ghost,
                      onPressed: () {
                        showAppModal(
                          context: context,
                          title: 'Edit future structure',
                          maxWidth: 560,
                          child: StructureEditor(
                            structure: structure,
                            currentLevel: 0,
                            anteStyle: settings.anteStyle,
                            onSpeedUp: () {
                              app.acceptSpeedRecommendation(rec: SpeedRecommendation.speedUp);
                              Navigator.of(context).pop();
                            },
                            onSlowDown: () {
                              app.acceptSpeedRecommendation(rec: SpeedRecommendation.slowDown);
                              Navigator.of(context).pop();
                            },
                            onApply: (edits) {
                              if (edits.isNotEmpty) app.applyLevelEdits(edits);
                              Navigator.of(context).pop();
                            },
                          ),
                        );
                      },
                      child: const Text('Edit'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    children: const [
                      Expanded(child: _LevelCell(label: 'Level', align: TextAlign.left)),
                      Expanded(child: _LevelCell(label: 'Small', align: TextAlign.right)),
                      Expanded(child: _LevelCell(label: 'Big', align: TextAlign.right)),
                      Expanded(child: _LevelCell(label: 'Ante', align: TextAlign.right)),
                      Expanded(child: _LevelCell(label: 'BB Depth', align: TextAlign.right)),
                    ],
                  ),
                ),
                const Divider(color: AppColors.border, height: 1),
                for (var i = 0; i < structure.levels.length; i++)
                  Builder(builder: (context) {
                    final l = structure.levels[i];
                    final isRebuyClose = settings.rebuys && l.level == settings.rebuysCloseLevel;
                    final isAnteStart = l.ante != null && (i == 0 || structure.levels[i - 1].ante == null);
                    final bbDepth = (structure.startingStack / l.bb).round();
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isAnteStart ? AppColors.primarySoft.withValues(alpha: 0.15) : null,
                        border: isRebuyClose
                            ? const Border(bottom: BorderSide(color: AppColors.primary, width: 2))
                            : const Border(bottom: BorderSide(color: AppColors.hairlineBorder)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${l.level}',
                              style: AppTypography.monoXs.copyWith(color: AppColors.mutedForeground),
                            ),
                          ),
                          Expanded(child: Text(Formatters.chips(l.sb), textAlign: TextAlign.right, style: AppTypography.monoXs)),
                          Expanded(
                            child: Text(
                              Formatters.chips(l.bb),
                              textAlign: TextAlign.right,
                              style: AppTypography.monoXs.copyWith(color: AppColors.foreground, fontWeight: FontWeight.w500),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              l.ante != null ? Formatters.chips(l.ante!) : '—',
                              textAlign: TextAlign.right,
                              style: AppTypography.monoXs.copyWith(
                                color: l.ante != null ? AppColors.accent : AppColors.mutedForeground,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '$bbDepth',
                              textAlign: TextAlign.right,
                              style: AppTypography.monoXs.copyWith(color: AppColors.mutedForeground),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                if (settings.rebuys)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      'Rebuys close after Level ${settings.rebuysCloseLevel}.'
                      '${settings.anteEnabled && anteStartLevel > 0 ? ' Ante starts Level $anteStartLevel.' : ''}',
                      style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Prize distribution
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Prize distribution (admin only)', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
                    SizedBox(
                      width: 140,
                      child: AppSelect<int?>(
                        value: settings.forcePaidPlaces,
                        hint: 'Auto-calculate',
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('Auto')),
                          for (var i = 1; i <= 10; i++)
                            DropdownMenuItem<int?>(value: i, child: Text('$i paid places')),
                        ],
                        onChanged: (v) => app.overridePaidPlaces(v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Based on ${settings.players} players + estimated rebuys${settings.addOn ? ' + add-ons' : ''}. Players will see prize pool total only.',
                  style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final p in structure.prizes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Text(const ['🥇', '🥈', '🥉', '4th'][p.place - 1], style: const TextStyle(fontSize: AppFontSizes.md)),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            const ['1st Place', '2nd Place', '3rd Place', '4th Place'][p.place - 1],
                            style: AppTypography.bodySm,
                          ),
                        ),
                        Text(
                          '${p.amount}',
                          style: AppTypography.monoSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                const Divider(color: AppColors.border),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Row(
                    children: [
                      Text('Est. prize pool', style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
                      const Spacer(),
                      Text(
                        '${structure.prizePool}',
                        style: AppTypography.monoXs.copyWith(color: AppColors.foreground),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      Text(
                        'Est. organiser amount (${settings.organizerPct}%)',
                        style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                      ),
                      const Spacer(),
                      Text('${structure.organizerAmount}', style: AppTypography.monoXs.copyWith(color: AppColors.foreground)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Color-up instructions
          if (structure.colorUpInstructions.isNotEmpty) ...[
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Color-up at rebuy close', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.sm),
                  for (final ins in structure.colorUpInstructions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('→', style: AppTypography.bodySm.copyWith(color: AppColors.primary)),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(ins, style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          // Actions
          Row(
            children: [
              Expanded(
                child: AppButton(
                  variant: AppButtonVariant.secondary,
                  onPressed: () => context.go(RoutePaths.createTournament),
                  child: const Text('← Edit settings'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  variant: AppButtonVariant.secondary,
                  onPressed: () {
                    // Regenerate with same params
                    app.setCurrentGame(app.createGame(settings));
                  },
                  child: const Text('↻ Regenerate'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  onPressed: () {
                    app.updateGameStatus(LiveGameStatus.published);
                    context.go(RoutePaths.invitation);
                  },
                  child: const Text('Confirm & Publish →'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Text(label, style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.mono(size: AppFontSizes.md, weight: FontWeight.w700, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _LevelCell extends StatelessWidget {
  const _LevelCell({required this.label, required this.align});

  final String label;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: align,
      style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground, fontWeight: FontWeight.w500),
    );
  }
}

class _ChipDot extends StatelessWidget {
  const _ChipDot({required this.hex, required this.value});

  final int hex;
  final int value;

  @override
  Widget build(BuildContext context) {
    final label = value >= 1000 ? '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K' : '$value';
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color(hex),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Text(
        label,
        style: AppTypography.mono(
          size: 8,
          weight: FontWeight.w700,
          color: Colors.white,
        ).copyWith(shadows: const [Shadow(color: AppColors.shadowDeep, blurRadius: 2)]),
      ),
    );
  }
}
