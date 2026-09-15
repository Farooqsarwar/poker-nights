import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/live_game.dart';
import '../../models/tournament.dart';
import '../../providers/app_provider.dart';
import '../../widgets/ai_insights_panel.dart';
import '../../widgets/premium_gate.dart';
import '../../services/entitlements.dart';
import '../../utils/formatters.dart';
import '../../utils/tournament_engine.dart';
import '../../widgets/app_alert_banner.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_icon_label.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_select.dart';
import '../../widgets/glass_styles.dart';
import '../../widgets/medal_icon.dart';
import '../../widgets/screen_shell.dart';
import '../../widgets/structure_editor.dart';
import '../../widgets/count_stepper.dart';

/// Structure review mirroring the web `StructureReviewPage`.
class StructureReviewScreen extends StatelessWidget {
  const StructureReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final game = app.currentGame;
    final isAdmin = app.isAdmin;

    if (!isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(RoutePaths.invitation);
      });
      return const SizedBox.shrink();
    }

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
    // Playing time the structure is PLANNED to take, not the length of every
    // level it contains. The generator appends a spare tail so a slow field
    // cannot run off the end (11-014), and those levels are meant to go
    // unused — folding them in made a 3.5 h event predict a finish an hour
    // late on the very screen where the host approves the structure (11-030,
    // User Flow section 4.8 / Appendix A.3). `expectedFinishMins` is the
    // engine's own answer and already includes the settlement pause (11-031);
    // fall back to the planned levels for a structure generated before that
    // field existed.
    final plannedMins = structure.levels
        .take(structure.effectivePlannedLevels)
        .fold<int>(0, (s, l) => s + l.durationMins);
    final totalMins = structure.expectedFinishMins > 0
        ? structure.expectedFinishMins
        : plannedMins + TournamentEngine.settlementBreakMins;
    final anteStartLevel =
        structure.levels.indexWhere((l) => l.ante != null) + 1;
    final expectedRebuys = settings.rebuys
        ? (settings.players * 0.35).round()
        : 0;
    final expectedAddOns = settings.addOn
        ? (settings.players * 0.65).round()
        : 0;
    final totalChips =
        settings.players * structure.startingStack +
        expectedRebuys * structure.rebuyStack +
        expectedAddOns * structure.addOnStack;
    final hasStructure = structure.levels.isNotEmpty;

    String hhmm(DateTime dt) =>
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    if (!hasStructure) {
      final checkedInCount = game.confirmedCount;
      return AppPage(
        maxWidth: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () => context.go(RoutePaths.invitation),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xs),
                    child: Icon(
                      Icons.arrow_back,
                      size: AppFontSizes.xl,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Structure Review',
                      style: AppTypography.display(
                        size: AppFontSizes.xxxl,
                        weight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      settings.name,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.settings_suggest,
                    size: 32,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Ready to generate final structure',
                    style: AppTypography.bodyLg.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'The AI will calculate starting stacks, blinds, and levels based on '
                    'the $checkedInCount checked-in players, target duration, and available chips.',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    fullWidth: true,
                    size: AppButtonSize.lg,
                    onPressed: () async {
                      // Show the splash animation while "generating"
                      showGeneratingModal(
                        context: context,
                        message: 'AI is generating structure...',
                      );
                      // Fake delay to show off the animation
                      await Future.delayed(const Duration(seconds: 3));
                      if (!context.mounted) return;
                      // Generate and close dialog
                      context.read<AppProvider>().generateFinalStructure(checkedInCount);
                      Navigator.of(context).pop();
                    },
                    child: const AppIconLabel(
                      label: 'Generate Final Structure',
                      trailing: Icons.auto_awesome,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      );
    }

    // Predicted finish as a clock-time window around the estimated end
    // (spec example: "Expected finish: 23:25–23:50").
    final start = settings.scheduledStart;
    final finishWindow = start == null
        ? null
        : '${hhmm(start.add(Duration(minutes: totalMins - 10)))}–'
              '${hhmm(start.add(Duration(minutes: totalMins + 15)))}';

    return AppPage(
      maxWidth: 640,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => context.go(RoutePaths.invitation),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Icon(
                    Icons.arrow_back,
                    size: AppFontSizes.xl,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Structure Review',
                      style: AppTypography.display(
                        size: AppFontSizes.xxxl,
                        weight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      settings.name,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppAlertBanner(
            type: AppAlertType.info,
            message: game.structureConfirmed
                ? 'Structure confirmed. Starting stacks freeze when the tournament starts; blinds, level durations and the player count stay editable.'
                : 'AI estimate based on ${settings.players} expected players (from RSVPs) — review, edit or regenerate before the game.',
          ),
          const SizedBox(height: AppSpacing.lg),
          // Section 2 requires the depth explanation in plain language; it was
          // being computed and shown nowhere. Free, because the spec requires
          // it. The deeper analysis below it is section 3's "Advanced AI
          // recommendations" and is gated.
          AiInsightsPanel(
            structure: structure,
            settings: settings,
            tier: app.premiumTier,
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final w in structure.warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppAlertBanner(type: AppAlertType.warning, message: w),
            ),
          // Chip inventory check (§4.5): compare the plan's total chip demand
          // (starting stacks + expected rebuys + expected add-ons) against the
          // physical chips the host owns. Shortages are flagged before publish.
          ..._chipShortages(structure, settings).map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppAlertBanner(type: AppAlertType.error, message: s),
            ),
          ),
          // Summary cards — use responsive widths so they don't overflow
          // on screens narrower than 360px.
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth < 400
                  ? constraints.maxWidth
                  : (constraints.maxWidth / 3).floorToDouble().clamp(100.0, 180.0);
              return Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _PlayerCountCard(
                      players: settings.players,
                      isAdmin: isAdmin,
                      onChanged: (v) => app.updateStructurePlayerCount(v),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _SummaryCard(
                      label: 'Starting stack',
                      value: Formatters.chips(structure.startingStack),
                    ),
                  ),
              SizedBox(
                width: cardWidth,
                child: _SummaryCard(
                  label: 'Total chips',
                  value: Formatters.chips(totalChips),
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _SummaryCard(
                  label: 'Level duration',
                  value: '${structure.levelDuration}m',
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _SummaryCard(
                  label: 'Levels',
                  value: '${structure.levels.length}',
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _SummaryCard(
                  label: 'Est. finish',
                  value: finishWindow ?? Formatters.duration(totalMins),
                ),
              ),
            ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          // Starting chip plan
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Starting stack — '
                        '${Formatters.chips(structure.startingStack)}',
                        style: AppTypography.bodySm.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Technical section 17 lists Regenerate, EDIT and Confirm
                    // as the three actions on the estimate. The blind schedule
                    // below already has its own editor; the stack had none, so
                    // the only way to change it was Recalculate — which throws
                    // away every manual edit. This adjusts it in place.
                    AppButton(
                      size: AppButtonSize.sm,
                      variant: AppButtonVariant.ghost,
                      onPressed: () => _showAdjustModal(context, app, structure),
                      child: const Text('Adjust'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                for (final c in structure.chipPlan)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        _ChipDot(hex: c.hex, value: c.value),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(c.color, style: AppTypography.bodySm),
                        ),
                        Text(
                          '×${c.count}',
                          style: AppTypography.monoSm.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        SizedBox(
                          width: 72,
                          child: Text(
                            Formatters.chips(c.total),
                            textAlign: TextAlign.right,
                            style: AppTypography.monoSm.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (settings.rebuys) ...[
                  Container(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rebuy stack — ${Formatters.chips(structure.rebuyStack)}',
                          style: AppTypography.bodyXs.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final c in structure.rebuyChipPlan)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                _ChipDot(hex: c.hex, value: c.value),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Text(
                                    c.color,
                                    style: AppTypography.bodyXs,
                                  ),
                                ),
                                Text(
                                  '×${c.count}',
                                  style: AppTypography.monoXs,
                                ),
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
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                      ),
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
                    Expanded(
                      child: Text(
                        'Blind schedule — ${structure.levelDuration}-minute levels',
                        style: AppTypography.bodySm.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    PremiumLock(
                      tier: app.premiumTier,
                      feature: PremiumFeature.aiOptimisedStructures,
                      child: AppButton(
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
                              app.acceptSpeedRecommendation(
                                rec: SpeedRecommendation.speedUp,
                              );
                              Navigator.of(context).pop();
                            },
                            onSlowDown: () {
                              app.acceptSpeedRecommendation(
                                rec: SpeedRecommendation.slowDown,
                              );
                              Navigator.of(context).pop();
                            },
                            onApply: (levels) {
                              if (levels.isNotEmpty) {
                                app.applyFutureLevels(levels);
                              }
                              Navigator.of(context).pop();
                            },
                          ),
                        );
                      },
                      child: const Text('Edit'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    children: const [
                      Expanded(
                        child: _LevelCell(
                          label: 'Level',
                          align: TextAlign.left,
                        ),
                      ),
                      Expanded(
                        child: _LevelCell(
                          label: 'Small',
                          align: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        child: _LevelCell(label: 'Big', align: TextAlign.right),
                      ),
                      Expanded(
                        child: _LevelCell(
                          label: 'Ante',
                          align: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        child: _LevelCell(
                          label: 'BB Depth',
                          align: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(color: AppColors.border, height: 1),
                for (var i = 0; i < structure.levels.length; i++)
                  Builder(
                    builder: (context) {
                      final l = structure.levels[i];
                      final isRebuyClose =
                          settings.rebuys &&
                          l.level == settings.rebuysCloseLevel;
                      final isAnteStart =
                          l.ante != null &&
                          (i == 0 || structure.levels[i - 1].ante == null);
                      final bbDepth = (structure.startingStack / l.bb).round();
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: isAnteStart
                              ? AppColors.primarySoft.withValues(alpha: 0.15)
                              : null,
                          border: isRebuyClose
                              ? Border(
                                  bottom: BorderSide(
                                    color: AppColors.primary,
                                    width: 2,
                                  ),
                                )
                              : Border(
                                  bottom: BorderSide(
                                    color: AppColors.hairlineBorder,
                                  ),
                                ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    '${l.level}',
                                    style: AppTypography.monoXs.copyWith(
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                  // Section 11 requires manual edits to carry
                                  // a visible marker, so the host can see
                                  // which rows are theirs before recalculating
                                  // rather than finding out afterwards.
                                  if (l.manuallyEdited) ...[
                                    const SizedBox(width: 4),
                                    Tooltip(
                                      message: 'Edited by hand',
                                      child: Icon(
                                        Icons.edit_outlined,
                                        size: 11,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Expanded(
                              child: Text(
                                Formatters.chips(l.sb),
                                textAlign: TextAlign.right,
                                style: AppTypography.monoXs,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                Formatters.chips(l.bb),
                                textAlign: TextAlign.right,
                                style: AppTypography.monoXs.copyWith(
                                  color: AppColors.foreground,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                l.ante != null
                                    ? Formatters.chips(l.ante!)
                                    : '—',
                                textAlign: TextAlign.right,
                                style: AppTypography.monoXs.copyWith(
                                  color: l.ante != null
                                      ? AppColors.accent
                                      : AppColors.mutedForeground,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '$bbDepth',
                                textAlign: TextAlign.right,
                                style: AppTypography.monoXs.copyWith(
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                if (settings.rebuys)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      'Rebuys close after Level ${settings.rebuysCloseLevel}.'
                      '${settings.anteEnabled && anteStartLevel > 0 ? ' Ante starts Level $anteStartLevel.' : ''}',
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                      ),
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
                    Expanded(
                      child: Text(
                        'Prize distribution (admin only)',
                        style: AppTypography.bodySm.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: AppSelect<int?>(
                        value: settings.forcePaidPlaces,
                        hint: 'Auto-calculate',
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Auto'),
                          ),
                          for (var i = 1; i <= 10; i++)
                            DropdownMenuItem<int?>(
                              value: i,
                              child: Text('$i paid places'),
                            ),
                        ],
                        onChanged: (v) => app.overridePaidPlaces(v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                if (!game.settlementConfirmed) ...[
                  const SizedBox(height: AppSpacing.md),
                  Icon(
                    Icons.lock_outline,
                    size: 28,
                    color: AppColors.mutedForeground,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Distribution calculated at rebuy close',
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Prices are calculated at the end of Level ${settings.rebuysCloseLevel}, '
                    'when the exact number of players, actual rebuys and selected add-ons are known.',
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const Divider(height: AppSpacing.lg),
                ] else ...[
                  Text(
                    'Based on ${settings.players} players + estimated rebuys${settings.addOn ? ' + add-ons' : ''}. Players will see prize pool total only.',
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final p in structure.prizes)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          p.place <= 3
                              ? SizedBox(
                                  width: 24,
                                  child: Center(
                                    child: MedalIcon(
                                      p.place,
                                      size: AppFontSizes.md,
                                    ),
                                  ),
                                )
                              : SizedBox(
                                  width: 24,
                                  child: Center(
                                    child: Text(
                                      _placeLabel(p.place),
                                      style: AppTypography.bodyXs.copyWith(
                                        color: AppColors.mutedForeground,
                                      ),
                                    ),
                                  ),
                                ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _placeName(p.place),
                              style: AppTypography.bodySm,
                            ),
                          ),
                          Text(
                            '${p.amount}',
                            style: AppTypography.monoSm.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Divider(color: AppColors.border),
                ],
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Row(
                    children: [
                      Text(
                        'Est. prize pool',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${structure.prizePool}',
                        style: AppTypography.monoXs.copyWith(
                          color: AppColors.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      // Label is the percentage; the value shows the resulting
                      // amount (audit fix: the row used to print the amount
                      // under a "(%)" label).
                      Text(
                        'Organizational costs · ${settings.organizerPct}%',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${structure.organizerAmount}',
                        style: AppTypography.monoXs.copyWith(
                          color: AppColors.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
                // 14-010 / 14-011: the residue is a ROUNDING REMAINDER, never
                // an organizer cut. Rendered only when it exists so a 0% game
                // does not grow a mysterious retained line.
                if (structure.roundingRemainder > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Text(
                          'Rounding remainder',
                          style: AppTypography.bodyXs.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${structure.roundingRemainder}',
                          style: AppTypography.monoXs.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
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
                  Text(
                    'Color-up at rebuy close',
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final ins in structure.colorUpInstructions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.arrow_forward,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              ins,
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.mutedForeground,
                              ),
                            ),
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
                  onPressed: () => context.go(RoutePaths.invitation),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back, size: 14, color: AppColors.icon),
                        SizedBox(width: 6),
                        Text('Edit settings'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  variant: AppButtonVariant.secondary,
                  onPressed: () {
                    final manualCount = app.manuallyEditedFutureLevels();
                    showAppModal(
                      context: context,
                      title: 'Recalculate structure',
                      maxWidth: 440,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Recalculating regenerates the blinds, levels and '
                            'prize distribution from the current settings and '
                            'attendance. Starting stacks stay frozen once the '
                            'tournament has started.',
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                          // Sections 11 and 29: manual edits are never
                          // silently overwritten. With none, this stays out of
                          // the way; with some, the host is told how many and
                          // chooses. Keeping them is the default action.
                          if (manualCount > 0) ...[
                            const SizedBox(height: AppSpacing.md),
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                                border: Border.all(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                'You have hand-edited $manualCount future '
                                'level${manualCount == 1 ? '' : 's'}. Keep '
                                'them, or let the recalculation replace them?',
                                style: AppTypography.bodySm.copyWith(
                                  color: AppColors.foreground,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                          if (manualCount > 0) ...[
                            AppButton(
                              fullWidth: true,
                              onPressed: () {
                                app.recalculateStructure();
                                Navigator.of(context).pop();
                              },
                              child: Text(
                                'Recalculate, keep my $manualCount '
                                'level${manualCount == 1 ? '' : 's'}',
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            AppButton(
                              fullWidth: true,
                              variant: AppButtonVariant.destructive,
                              onPressed: () {
                                app.recalculateStructure(
                                  keepManualLevels: false,
                                );
                                Navigator.of(context).pop();
                              },
                              child: const Text('Replace my edits'),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            AppButton(
                              fullWidth: true,
                              variant: AppButtonVariant.secondary,
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                          ] else
                            Row(
                              children: [
                                Expanded(
                                  child: AppButton(
                                    variant: AppButtonVariant.secondary,
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('Keep current'),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: AppButton(
                                    onPressed: () {
                                      app.recalculateStructure();
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('Recalculate'),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh, size: 14, color: AppColors.icon),
                        SizedBox(width: 6),
                        Text('Recalculate'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  onPressed: () async {
                    // Show the splash animation while "generating/publishing"
                    showGeneratingModal(
                      context: context,
                      message: 'AI is generating structure...',
                    );
                    // Fake delay to show off the animation
                    await Future.delayed(const Duration(seconds: 3));
                    if (!context.mounted) return;
                    
                    app.confirmStructure();
                    Navigator.of(context).pop();
                    context.go(RoutePaths.invitation);
                  },
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Confirm & Publish'),
                        SizedBox(width: 6),
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: AppColors.icon,
                        ),
                      ],
                    ),
                  ),
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


/// Section 17's "Edit" action: nudge the estimate without rebuilding it.
///
/// The two dimensions a host actually wants to move are the starting stack
/// (rounder numbers are easier to hand out and count) and the level length
/// (the whole night runs long or short). Blinds, prizes and paid places are
/// deliberately left alone — a host who wants those rebuilt has Recalculate
/// right next to this.
void _showAdjustModal(
  BuildContext context,
  AppProvider app,
  TournamentStructure structure,
) {
  final locked = app.currentGame?.stacksLocked ?? false;
  var stack = structure.startingStack;

  // Step by something countable: 5% of the stack rounded to a round number,
  // never finer than the smallest chip in play.
  final chipValues = (app.currentGame?.settings.chipSet ?? const [])
      .map((c) => c.value)
      .where((v) => v > 0)
      .toList()
    ..sort();
  final minChip = chipValues.isEmpty ? 25 : chipValues.first;
  final rawStep = (structure.startingStack * 0.05).round();
  final step = rawStep <= minChip
      ? minChip
      : (rawStep ~/ minChip) * minChip;

  showAppModal(
    context: context,
    title: 'Adjust structure',
    maxWidth: 440,
    child: StatefulBuilder(
      builder: (modalContext, setModalState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Changes apply straight to this structure. Blinds, prizes and '
            'paid places stay exactly as they are, and nobody loses their '
            'RSVP or check-in.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Starting stack',
                      style: AppTypography.bodySm.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      locked
                          ? 'Frozen — play has started'
                          : 'In steps of $step',
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Opacity(
                opacity: locked ? 0.4 : 1,
                child: IgnorePointer(
                  ignoring: locked,
                  child: CountStepper(
                    value: stack,
                    min: step,
                    max: 1000000,
                    step: step,
                    semanticLabel: 'Starting stack',
                    onChanged: (v) => setModalState(() => stack = v),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Level lengths and individual blinds are edited from the blind '
            'schedule below.',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  variant: AppButtonVariant.secondary,
                  onPressed: () => Navigator.of(modalContext).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  onPressed: () {
                    final summary = app.adjustStructure(
                      startingStack: stack,
                    );
                    Navigator.of(modalContext).pop();
                    if (summary != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(summary)),
                      );
                    }
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
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
          Text(
            label,
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.mono(
              size: AppFontSizes.md,
              weight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerCountCard extends StatelessWidget {
  const _PlayerCountCard({
    required this.players,
    required this.onChanged,
    required this.isAdmin,
  });

  final int players;
  final ValueChanged<int> onChanged;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) {
      return _SummaryCard(label: 'Players', value: '$players');
    }
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: [
          Text(
            'Players',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                onTap: players > 2 ? () => onChanged(players - 1) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Icon(
                    Icons.remove,
                    size: 20,
                    color: players > 2 ? AppColors.primary : AppColors.muted,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$players',
                style: AppTypography.mono(
                  size: AppFontSizes.md,
                  weight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              InkWell(
                onTap: () => onChanged(players + 1),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                  child: Icon(Icons.add, size: 20, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _placeLabel(int place) {
  if (place % 100 >= 11 && place % 100 <= 13) return '${place}th';
  return switch (place % 10) {
    1 => '${place}st',
    2 => '${place}nd',
    3 => '${place}rd',
    _ => '${place}th',
  };
}

/// Computes the total chips required for the plan (starting stacks for every
/// expected player + expected rebuys + expected add-ons) and flags any
/// denomination where the host owns fewer chips than required (§4.5, 12-059).
List<String> _chipShortages(
  TournamentStructure structure,
  GameSettings settings,
) {
  final players = settings.players;
  final expectedRebuys = settings.rebuys ? (players * 0.35).round() : 0;
  final expectedAddOns = settings.addOn ? (players * 0.65).round() : 0;

  final required = <int, int>{};
  void add(List<ChipPlanEntry> plan, int factor) {
    for (final e in plan) {
      required[e.value] = (required[e.value] ?? 0) + e.count * factor;
    }
  }

  add(structure.chipPlan, players);
  add(structure.rebuyChipPlan, expectedRebuys);
  add(structure.addOnChipPlan, expectedAddOns);

  final shortages = <String>[];
  for (final chip in settings.chipSet) {
    final need = required[chip.value] ?? 0;
    if (chip.quantity < need) {
      shortages.add(
        'Chip shortage: you own ${chip.quantity} × ${chip.value} '
        '(${chip.color}) but the plan needs $need. '
        'Buy more, lower the buy-in, or reduce player count.',
      );
    }
  }
  return shortages;
}

String _placeName(int place) {
  if (place % 100 >= 11 && place % 100 <= 13) return '${place}th Place';
  return switch (place % 10) {
    1 => '${place}st Place',
    2 => '${place}nd Place',
    3 => '${place}rd Place',
    _ => '${place}th Place',
  };
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
      style: AppTypography.bodyXs.copyWith(
        color: AppColors.mutedForeground,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _ChipDot extends StatelessWidget {
  const _ChipDot({required this.hex, required this.value});

  final int hex;
  final int value;

  @override
  Widget build(BuildContext context) {
    final label = value >= 1000
        ? '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K'
        : '$value';
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color(hex),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.border,
          width: 1.5,
        ),
      ),
      child: Text(
        label,
        style:
            AppTypography.mono(
              size: 8,
              weight: FontWeight.w700,
              color: AppColors.foreground,
            ).copyWith(
              shadows: [
                Shadow(color: AppColors.shadowDeep, blurRadius: 2),
              ],
            ),
      ),
    );
  }
}
