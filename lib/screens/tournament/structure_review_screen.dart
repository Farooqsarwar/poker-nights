import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../widgets/app_tabs.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/back_nav_button.dart';
import '../../widgets/journey_progress.dart';
import '../../widgets/medal_icon.dart';
import '../../widgets/structure_editor.dart';
import '../../widgets/count_stepper.dart';
import '../../widgets/min_tap_target.dart';
import '../../widgets/squircle_icon_button.dart';

/// Structure review mirroring the web `StructureReviewPage`.
///
/// Split into two tabs, Parameters and Blind Structure. Everything that FEEDS
/// the generator sits on the first; everything the generator PRODUCED sits on
/// the second. Before the split this was one scroll long enough that the
/// numbers driving the blind curve and the curve itself could not be seen
/// together, and the inputs were the part that lost.
class StructureReviewScreen extends StatefulWidget {
  const StructureReviewScreen({super.key});

  @override
  State<StructureReviewScreen> createState() => _StructureReviewScreenState();
}

class _StructureReviewScreenState extends State<StructureReviewScreen> {
  static const _tabParams = 'params';
  static const _tabStructure = 'structure';

  String _tab = _tabParams;
  bool _isEditing = false;

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

    // Back honours the `?from=` query param so a host arriving from check-in
    // returns there; a bare link falls back to the invitation default.
    final backTo =
        RoutePaths.structureReviewFrom(GoRouterState.of(context).uri) ??
            RoutePaths.invitation;

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
    // The host's own figures when they set them, the engine's rates when they
    // did not. This used to inline `players * 0.35` and `players * 0.65`, a
    // third copy of constants that live in the model — so a host who raised
    // expected rebuys saw the blind curve move but this total stay put.
    final expectedRebuys = settings.effectiveExpectedRebuys;
    final expectedReEntries = settings.effectiveExpectedReEntries;
    final expectedAddOns = settings.effectiveExpectedAddOns;
    // A re-entry replaces a stack already counted, so only a re-entry stack
    // LARGER than the starting stack adds chips — the same rule the engine
    // applies when it sizes the final blind.
    final reEntryStack = settings.reEntryChips ?? structure.startingStack;
    final totalChips =
        settings.players * structure.startingStack +
        expectedRebuys * structure.rebuyStack +
        expectedReEntries *
            (reEntryStack - structure.startingStack).clamp(0, reEntryStack) +
        expectedAddOns * structure.addOnStack;
    final hasStructure = structure.levels.isNotEmpty;

    // The schedule in the order the clock plays it: every level with the
    // elapsed time it starts at, and the breaks sitting between them. Built
    // here rather than taken from ClockSequence because this table shows the
    // spare tail levels too — a host approving a structure should see the
    // headroom the engine left them, even though the clock plans to stop
    // before reaching it.
    final schedule = <_ScheduleRow>[];
    var elapsed = 0;
    for (var i = 0; i < structure.levels.length; i++) {
      final l = structure.levels[i];
      schedule.add(
        _ScheduleRow.level(index: i, startMins: elapsed),
      );
      elapsed += l.durationMins;
      for (final b in structure.breaks) {
        if (b.afterLevel == l.level && b.durationMins > 0) {
          schedule.add(
            _ScheduleRow.breakAfter(
              breakMins: b.durationMins,
              startMins: elapsed,
            ),
          );
          elapsed += b.durationMins;
        }
      }
    }

    // What the blind curve actually does, per level. Measured on the levels
    // the engine produced rather than re-derived from its target, so a
    // hand-edited structure reports the curve it now has instead of the one it
    // was generated as. Read-only: the growth factor is solved from the
    // starting stack, the level length and the finish target, and offering it
    // as an input would let a host contradict all three at once.
    final plannedLadder =
        structure.levels.take(structure.effectivePlannedLevels).toList();
    final growthPerLevel = plannedLadder.length >= 2 && plannedLadder.first.bb > 0
        ? math
            .pow(
              plannedLadder.last.bb / plannedLadder.first.bb,
              1 / (plannedLadder.length - 1),
            )
            .toDouble()
        : null;

    /// Elapsed playing time as h:mm — a stopwatch reading, not a wall clock.
    String elapsedClock(int mins) =>
        '${mins ~/ 60}:${(mins % 60).toString().padLeft(2, '0')}';

    String hhmm(DateTime dt) =>
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    if (!hasStructure) {
      final checkedInCount = game.confirmedCount;
      return AppPage(
        maxWidth: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Same journey strip the invitation and check-in screens carry
            // (Task C), so the host keeps one fixed sense of where they are
            // across all three pre-live screens.
            JourneyProgress(
              game: game,
              currentRoute: RoutePaths.structureReview,
              onStepTap: (step) => context.go(step.route),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                BackNavButton(onPressed: () => context.go(backTo)),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Review structure',
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
                  if (app.paceProposalPending) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _PaceProposalCard(app: app),
                  ],
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

    if (!_isEditing) {
      return AppPage(
        maxWidth: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top App Bar: Squircle back `<` button & `Step 5 of 5`
            Row(
              children: [
                SquircleIconButton(
                  icon: Icons.chevron_left,
                  size: 40,
                  borderRadius: 12,
                  backgroundColor: AppColors.card,
                  borderColor: AppColors.borderSubtle,
                  onPressed: () => context.go(backTo),
                ),
                const Spacer(),
                Text(
                  'Step 5 of 5',
                  style: TextStyle(
                    color: AppColors.mutedForeground,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Red progress indicator bar underneath app bar (100% full width gradient)
            Container(
              height: 2.5,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryHover],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Review structure',
              style: TextStyle(
                color: AppColors.foreground,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),

            // 3 Summary Cards: levels | est. length | per level
            Row(
              children: [
                Expanded(
                  child: _buildC2SummaryCard(
                    '${structure.levels.length}',
                    'levels',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildC2SummaryCard(
                    '~${(totalMins / 60).round()}h',
                    'est. length',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildC2SummaryCard(
                    '${structure.levelDuration}m',
                    'per level',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Structure Levels Card
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  for (var i = 0; i < schedule.length; i++) ...[
                    _buildC2ScheduleRow(schedule[i], structure),
                    if (i < schedule.length - 1)
                      Divider(height: 1, color: AppColors.muted),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Bottom Bar: Edit (dark squircle) & Publish event (crimson glowing)
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.card,
                        foregroundColor: AppColors.foreground,
                        side: BorderSide(color: AppColors.borderSubtle),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => setState(() => _isEditing = true),
                      child: const Text(
                        'Edit',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.foreground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        app.publishGame();
                        context.go(RoutePaths.invitation);
                      },
                      child: const Text(
                        'Publish event',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    }

    return AppPage(
      maxWidth: 640,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _isEditing = false),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back to review summary'),
              ),
            ),
          ),
          JourneyProgress(
            game: game,
            currentRoute: RoutePaths.structureReview,
            onStepTap: (step) => context.go(step.route),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              BackNavButton(onPressed: () => context.go(backTo)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Review structure',
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
          AppTabs(
            tabs: const [
              AppTabItem(id: _tabParams, label: 'Parameters'),
              AppTabItem(id: _tabStructure, label: 'Blind Structure'),
            ],
            active: _tab,
            onChanged: (id) => setState(() => _tab = id),
          ),
          const SizedBox(height: AppSpacing.lg),
          // ── Parameters tab ── everything that feeds the generator. The
          // sections below keep their original indentation; re-indenting six
          // hundred lines to sit under this guard would bury the change.
          if (_tab == _tabParams) ...[
          if (app.paceProposalPending) ...[
            _PaceProposalCard(app: app),
            const SizedBox(height: AppSpacing.lg),
          ],
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
          // Structure warnings and chip shortages (§4.5) share one expandable
          // alert row so a bad config reads as a single "N issues" line above
          // the parameters instead of a stack of banners. Display-only: every
          // item renders in full when expanded — nothing is dropped.
          _StructureReviewIssues(
            warnings: structure.warnings,
            shortages: _chipShortages(structure, settings),
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
          _GenerationParamsCard(
            settings: settings,
            startingStack: structure.startingStack,
            defaultLevelDuration: structure.levelDuration,
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
                              color: AppColors.primaryText,
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
          ],
          // ── Blind Structure tab ── everything the generator produced.
          if (_tab == _tabStructure) ...[
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
                if (growthPerLevel != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Blinds grow ×${growthPerLevel.toStringAsFixed(2)} a level '
                    'across the ${plannedLadder.length} planned levels — solved '
                    'from the starting stack, the level length and your finish '
                    'target.',
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    children: const [
                      Expanded(
                        flex: 2,
                        child: _LevelCell(
                          label: 'Level',
                          align: TextAlign.left,
                        ),
                      ),
                      // Elapsed playing time at the moment this level starts,
                      // breaks included. "Level 9" tells a host nothing about
                      // when they will be eating; "2:05" tells them exactly.
                      Expanded(
                        flex: 3,
                        child: _LevelCell(
                          label: 'Start',
                          align: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _LevelCell(
                          label: 'Min',
                          align: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: _LevelCell(
                          label: 'Small',
                          align: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: _LevelCell(label: 'Big', align: TextAlign.right),
                      ),
                      Expanded(
                        flex: 3,
                        child: _LevelCell(
                          label: 'Ante',
                          align: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: _LevelCell(
                          label: 'BB',
                          align: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(color: AppColors.border, height: 1),
                for (final row in schedule)
                  if (row.isBreak)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.35),
                        border: Border(
                          bottom: BorderSide(color: AppColors.hairlineBorder),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Icon(
                              Icons.free_breakfast_outlined,
                              size: 12,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              elapsedClock(row.startMins),
                              textAlign: TextAlign.right,
                              style: AppTypography.monoXs.copyWith(
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${row.breakMins}',
                              textAlign: TextAlign.right,
                              style: AppTypography.monoXs.copyWith(
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 12,
                            child: Text(
                              'Break',
                              textAlign: TextAlign.right,
                              style: AppTypography.bodyXs.copyWith(
                                color: AppColors.mutedForeground,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Builder(
                      builder: (context) {
                        final i = row.index;
                        final l = structure.levels[i];
                        final isRebuyClose = settings.rebuys &&
                            l.level == settings.rebuysCloseLevel;
                        final isAnteStart = l.ante != null &&
                            (i == 0 || structure.levels[i - 1].ante == null);
                        final bbDepth =
                            (structure.startingStack / l.bb).round();
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
                                flex: 2,
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
                                    // which rows are theirs before
                                    // recalculating rather than finding out
                                    // afterwards.
                                    if (l.manuallyEdited) ...[
                                      const SizedBox(width: AppSpacing.xs),
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
                                flex: 3,
                                child: Text(
                                  elapsedClock(row.startMins),
                                  textAlign: TextAlign.right,
                                  style: AppTypography.monoXs.copyWith(
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${l.durationMins}',
                                  textAlign: TextAlign.right,
                                  style: AppTypography.monoXs.copyWith(
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  Formatters.chips(l.sb),
                                  textAlign: TextAlign.right,
                                  style: AppTypography.monoXs,
                                ),
                              ),
                              Expanded(
                                flex: 3,
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
                                flex: 3,
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
                                flex: 3,
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
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Payout curve',
                        style: AppTypography.bodySm,
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: AppSelect<PayoutShape>(
                        value: settings.payoutShape,
                        items: [
                          for (final shape in PayoutShape.values)
                            DropdownMenuItem<PayoutShape>(
                              value: shape,
                              child: Text(shape.label),
                            ),
                        ],
                        onChanged: (v) {
                          if (v != null) app.setPayoutShape(v);
                        },
                      ),
                    ),
                  ],
                ),
                Text(
                  settings.payoutShape.blurb,
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
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
                  const SizedBox(height: AppSpacing.xxs),
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
                              color: AppColors.primaryText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // A last place that pays back less than it cost to enter is
                  // legal but rarely intended — it means the bubble is worth
                  // more than the min-cash. Shown, not blocked: the host may
                  // have chosen a deep flat curve on purpose.
                  if (structure.prizes.isNotEmpty &&
                      structure.prizes.last.amount < settings.buyIn)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: AppFontSizes.md,
                            color: AppColors.warningText,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              '${_placeName(structure.prizes.last.place)} pays '
                              '${structure.prizes.last.amount}, less than the '
                              '${settings.buyIn} buy-in. Pay fewer places, or '
                              'use a flatter curve, if you want the last paid '
                              'player to leave even.',
                              style: AppTypography.bodyXs.copyWith(
                                color: AppColors.mutedForeground,
                              ),
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
          ],
          // Actions — outside both tabs: confirming, regenerating and sharing
          // apply to the whole tournament, not to whichever tab is open.
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
                        Text('Publish event'),
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

  Widget _buildC2SummaryCard(String value, String caption) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontFamily: AppTypography.monoFamily,
                color: AppColors.foreground,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: TextStyle(
              color: AppColors.mutedForeground,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildC2ScheduleRow(_ScheduleRow row, TournamentStructure structure) {
    if (row.isBreak) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.coffee_outlined,
              size: 18,
              color: AppColors.successText,
            ),
            const SizedBox(width: 8),
            Text(
              'Break',
              style: TextStyle(
                color: AppColors.successText,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${row.breakMins}m',
              style: TextStyle(
                color: AppColors.mutedForeground,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final l = structure.levels[row.index];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              'L${l.level}',
              style: TextStyle(
                color: AppColors.primaryText,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${Formatters.chips(l.sb)} / ${Formatters.chips(l.bb)}',
            style: TextStyle(
              color: AppColors.foreground,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (l.ante != null && l.ante! > 0) ...[
            Text(
              ' +${Formatters.chips(l.ante!)}',
              style: TextStyle(
                color: AppColors.primaryText,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const Spacer(),
          Text(
            '${l.durationMins}m',
            style: TextStyle(
              color: AppColors.mutedForeground,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
);
  }


/// The numbers that drive the generator, as inputs instead of constants.
///
/// Expected rebuys, re-entries and add-ons were fixed rates — 35 %, 20 % and
/// 65 % of the field — and every entry handed over exactly one starting stack.
/// Both are guesses about a room the app has never seen, and they are not idle
/// guesses: all four feed `expectedTotalChips`, which sets the final blind,
/// which sets the growth rate of the whole schedule. A host whose group always
/// rebuys had no way to say so.
///
/// Level length was likewise one of three presets chosen from the tournament's
/// duration. Any length the engine will accept is now allowed.
///
/// Nothing here is required. Each box is prefilled with the figure the engine
/// would have used, so a host who opens this card and changes nothing gets
/// exactly the structure they got before — and Reset puts every box back.
class _GenerationParamsCard extends StatefulWidget {
  const _GenerationParamsCard({
    required this.settings,
    required this.startingStack,
    required this.defaultLevelDuration,
  });

  final GameSettings settings;

  /// The generated starting stack — the default chip amount for a rebuy, a
  /// re-entry and an add-on alike.
  final int startingStack;

  /// The level length the engine picked, shown when the host has not set one.
  final int defaultLevelDuration;

  @override
  State<_GenerationParamsCard> createState() => _GenerationParamsCardState();
}

class _GenerationParamsCardState extends State<_GenerationParamsCard> {
  final _rebuys = TextEditingController();
  final _reEntries = TextEditingController();
  final _addOns = TextEditingController();
  final _rebuyChips = TextEditingController();
  final _reEntryChips = TextEditingController();
  final _addOnChips = TextEditingController();
  final _levelMins = TextEditingController();

  /// Set by [_reset] so the next rebuild adopts the engine's figures outright
  /// instead of trying to preserve what the host had typed.
  bool _resetting = false;

  static int _rebuysOf(_GenerationParamsCard w) =>
      w.settings.effectiveExpectedRebuys;
  static int _reEntriesOf(_GenerationParamsCard w) =>
      w.settings.effectiveExpectedReEntries;
  static int _addOnsOf(_GenerationParamsCard w) =>
      w.settings.effectiveExpectedAddOns;
  static int _rebuyChipsOf(_GenerationParamsCard w) =>
      w.settings.rebuyChips ?? w.startingStack;
  static int _reEntryChipsOf(_GenerationParamsCard w) =>
      w.settings.reEntryChips ?? w.startingStack;
  static int _addOnChipsOf(_GenerationParamsCard w) =>
      w.settings.addOnChips ?? w.startingStack;
  static int _levelMinsOf(_GenerationParamsCard w) =>
      w.settings.levelDurationMins ?? w.defaultLevelDuration;

  @override
  void initState() {
    super.initState();
    _fillFrom(widget);
  }

  @override
  void didUpdateWidget(covariant _GenerationParamsCard old) {
    super.didUpdateWidget(old);
    if (_resetting) {
      _resetting = false;
      _fillFrom(widget);
      return;
    }
    // Resync only the boxes the host has not touched. Changing the player
    // count moves the engine's own estimate, and a stale number left sitting
    // in a box would be written back as a deliberate override on the next
    // Apply — silently pinning the field to a figure nobody chose.
    _resync(_rebuys, _rebuysOf(old), _rebuysOf(widget));
    _resync(_reEntries, _reEntriesOf(old), _reEntriesOf(widget));
    _resync(_addOns, _addOnsOf(old), _addOnsOf(widget));
    _resync(_rebuyChips, _rebuyChipsOf(old), _rebuyChipsOf(widget));
    _resync(_reEntryChips, _reEntryChipsOf(old), _reEntryChipsOf(widget));
    _resync(_addOnChips, _addOnChipsOf(old), _addOnChipsOf(widget));
    _resync(_levelMins, _levelMinsOf(old), _levelMinsOf(widget));
  }

  void _fillFrom(_GenerationParamsCard w) {
    _rebuys.text = '${_rebuysOf(w)}';
    _reEntries.text = '${_reEntriesOf(w)}';
    _addOns.text = '${_addOnsOf(w)}';
    _rebuyChips.text = '${_rebuyChipsOf(w)}';
    _reEntryChips.text = '${_reEntryChipsOf(w)}';
    _addOnChips.text = '${_addOnChipsOf(w)}';
    _levelMins.text = '${_levelMinsOf(w)}';
  }

  void _resync(TextEditingController c, int was, int now) {
    if (was == now) return;
    if (c.text.trim() == '$was') c.text = '$now';
  }

  @override
  void dispose() {
    _rebuys.dispose();
    _reEntries.dispose();
    _addOns.dispose();
    _rebuyChips.dispose();
    _reEntryChips.dispose();
    _addOnChips.dispose();
    _levelMins.dispose();
    super.dispose();
  }

  int _read(TextEditingController c, int fallback, {required int min, required int max}) {
    final v = int.tryParse(c.text.trim()) ?? fallback;
    return v.clamp(min, max);
  }

  void _apply() {
    final s = widget.settings;
    // An unreadable or out-of-range box is corrected rather than refused: the
    // clamped figure is written straight back, so the host sees the number
    // that was actually used instead of a rejection they have to decode.
    final levelMins = _read(
      _levelMins,
      _levelMinsOf(widget),
      min: TournamentEngine.kMinLevelDurationMins,
      max: TournamentEngine.kMaxLevelDurationMins,
    );
    final rebuys = _read(_rebuys, _rebuysOf(widget), min: 0, max: 9999);
    final reEntries =
        _read(_reEntries, _reEntriesOf(widget), min: 0, max: 9999);
    final addOns = _read(_addOns, _addOnsOf(widget), min: 0, max: 9999);
    final rebuyChips =
        _read(_rebuyChips, _rebuyChipsOf(widget), min: 1, max: 100000000);
    final reEntryChips =
        _read(_reEntryChips, _reEntryChipsOf(widget), min: 1, max: 100000000);
    final addOnChips =
        _read(_addOnChips, _addOnChipsOf(widget), min: 1, max: 100000000);

    _levelMins.text = '$levelMins';
    _rebuys.text = '$rebuys';
    _reEntries.text = '$reEntries';
    _addOns.text = '$addOns';
    _rebuyChips.text = '$rebuyChips';
    _reEntryChips.text = '$reEntryChips';
    _addOnChips.text = '$addOnChips';

    // A disabled entry type's boxes are not shown, so they are not sent —
    // passing null leaves whatever was stored alone rather than writing a
    // figure for something the tournament does not offer.
    context.read<AppProvider>().updateGenerationParams(
          levelDurationMins: levelMins,
          expectedRebuys: s.rebuys ? rebuys : null,
          rebuyChips: s.rebuys ? rebuyChips : null,
          expectedReEntries: s.reEntry ? reEntries : null,
          reEntryChips: s.reEntry ? reEntryChips : null,
          expectedAddOns: s.addOn ? addOns : null,
          addOnChips: s.addOn ? addOnChips : null,
        );
    FocusScope.of(context).unfocus();
  }

  void _reset() {
    _resetting = true;
    context.read<AppProvider>().updateGenerationParams(reset: true);
    FocusScope.of(context).unfocus();
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    String? hint,
  }) {
    return AppTextField(
      controller: controller,
      label: label,
      hint: hint,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onSubmitted: (_) => _apply(),
    );
  }

  Widget _pair(Widget left, Widget? right) {
    if (right == null) return left;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: right),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Generation parameters',
            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'What you expect to happen on the night. These set the total chips '
            'in play, which sets how fast the blinds have to climb.',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _numberField(
            _levelMins,
            'Level length (minutes)',
            hint: '${TournamentEngine.kMinLevelDurationMins}–'
                '${TournamentEngine.kMaxLevelDurationMins} minutes',
          ),
          if (s.rebuys) ...[
            const SizedBox(height: AppSpacing.md),
            _pair(
              _numberField(_rebuys, 'Expected rebuys'),
              _numberField(_rebuyChips, 'Rebuy chips'),
            ),
          ],
          if (s.reEntry) ...[
            const SizedBox(height: AppSpacing.md),
            _pair(
              _numberField(_reEntries, 'Expected re-entries'),
              _numberField(
                _reEntryChips,
                'Re-entry chips',
                hint: 'Only chips above the starting stack are new chips.',
              ),
            ),
          ],
          if (s.addOn) ...[
            const SizedBox(height: AppSpacing.md),
            _pair(
              _numberField(_addOns, 'Expected add-ons'),
              _numberField(_addOnChips, 'Add-on chips'),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  onPressed: _apply,
                  child: const AppIconLabel(
                    label: 'Apply & rebuild',
                    trailing: Icons.auto_awesome,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton(
                variant: AppButtonVariant.secondary,
                onPressed: _reset,
                child: const Text('Reset'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// §10.1. The proposal card: the measured average and the percentage shown
/// BEFORE generation, with an explicit accept/decline. Nothing here is ever
/// applied silently — [AppProvider.acceptPaceAdjustment] only runs when the
/// host presses Accept.
class _PaceProposalCard extends StatelessWidget {
  const _PaceProposalCard({required this.app});

  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    final proposal = app.paceProposal;
    if (proposal == null) return const SizedBox.shrink();
    final pctLabel = (proposal.adjustmentPct.abs() * 100).toStringAsFixed(1);
    final runsLong = proposal.adjustmentPct > 0;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                "This group's own pace",
                style: AppTypography.bodySm.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Over the last ${proposal.sampleSize} nights this group averaged '
            '${proposal.meanActualMins.round()} min — '
            '${proposal.meanOverageMins.abs().round()} min '
            '${runsLong ? 'over' : 'under'} the ${proposal.targetDurationMins} '
            'min target. Accepting will ${runsLong ? 'shorten' : 'lengthen'} '
            'levels by $pctLabel% before generating.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppButton(
                size: AppButtonSize.sm,
                onPressed: () => app.acceptPaceAdjustment(),
                child: Text(
                  'Accept ($pctLabel% ${runsLong ? 'shorter' : 'longer'})',
                ),
              ),
              AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.secondary,
                onPressed: () => app.declinePaceAdjustment(),
                child: const Text('Keep as planned'),
              ),
            ],
          ),
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
          Text(
            label,
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
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
          const SizedBox(height: AppSpacing.xxs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Tooltip(
                message: 'One fewer player',
                child: InkWell(
                  onTap: players > 2 ? () => onChanged(players - 1) : null,
                  child: MinTapTarget(
                    child: Icon(
                      Icons.remove,
                      size: 20,
                      color: players > 2 ? AppColors.primary : AppColors.muted,
                    ),
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
              Tooltip(
                message: 'One more player',
                child: InkWell(
                  onTap: () => onChanged(players + 1),
                  child: MinTapTarget(
                    child: Icon(
                      Icons.add,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
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

/// One row of the blind schedule table: a level, or a break between two.
///
/// Levels are held by index rather than by value so the row can still reach
/// the level before it — the ante-start highlight needs the neighbour, and a
/// break row sitting in between must not shift what "before" means.
class _ScheduleRow {
  const _ScheduleRow.level({required this.index, required this.startMins})
      : breakMins = null;

  const _ScheduleRow.breakAfter({
    required int this.breakMins,
    required this.startMins,
  }) : index = -1;

  final int index;
  final int? breakMins;

  /// Elapsed playing time, in minutes, when this row begins.
  final int startMins;

  bool get isBreak => breakMins != null;
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

/// Collapses the structure warnings and chip shortages (§4.5) into one
/// expandable alert row. A bad config used to stack five or six full banners
/// above the parameters; now it reads `⚠ N issues — tap to review`, and every
/// warning and shortage arrives as its own row when expanded. The banner
/// follows [AppAlertBanner]'s colour scheme — error when a shortage is present,
/// warning otherwise.
class _StructureReviewIssues extends StatefulWidget {
  const _StructureReviewIssues({
    required this.warnings,
    required this.shortages,
  });

  final List<String> warnings;
  final List<String> shortages;

  @override
  State<_StructureReviewIssues> createState() => _StructureReviewIssuesState();
}

class _StructureReviewIssuesState extends State<_StructureReviewIssues> {
  /// Unpayable chip denominations block the night physically, so any shortage
  /// opens the row expanded by default; a config raising only warnings starts
  /// collapsed.
  late bool _expanded = widget.shortages.isNotEmpty;

  @override
  void didUpdateWidget(covariant _StructureReviewIssues old) {
    super.didUpdateWidget(old);
    // Newly-appeared shortages (e.g. the player count was raised and the plan
    // rebuilt) must not hide under a collapsed row.
    if (widget.shortages.isNotEmpty && old.shortages.isEmpty) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = <({String message, IconData icon, Color color})>[
      for (final w in widget.warnings)
        (
          message: w,
          icon: Icons.warning_amber_rounded,
          color: AppColors.warningText,
        ),
      for (final s in widget.shortages)
        (
          message: s,
          icon: Icons.error_outline,
          color: AppColors.destructiveText,
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    final hasShortages = widget.shortages.isNotEmpty;
    final (background, border, foreground) = hasShortages
        ? (
            AppColors.destructiveSoft,
            AppColors.destructive,
            AppColors.destructiveForeground,
          )
        : (
            AppColors.warningSoft,
            AppColors.warning,
            AppColors.warningForeground,
          );

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Text(
                    '⚠',
                    style: AppTypography.bodySm.copyWith(color: foreground),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${rows.length} issue${rows.length == 1 ? '' : 's'} '
                      '— tap to review',
                      style: AppTypography.bodySm.copyWith(color: foreground),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: AppFontSizes.md,
                    color: foreground.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: AppDurations.fast,
            curve: Curves.easeOut,
            child: _expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Divider(color: AppColors.border, height: 1),
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0)
                          Divider(
                            color: AppColors.hairlineBorder,
                            height: 1,
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: 10,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Icon(
                                  rows[i].icon,
                                  size: 14,
                                  color: rows[i].color,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  rows[i].message,
                                  style: AppTypography.bodyXs.copyWith(
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
