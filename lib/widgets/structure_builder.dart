import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../models/chip_color.dart';
import '../models/tournament.dart';
import '../models/tournament_format.dart';
import '../utils/formatters.dart';
import '../utils/structure_builder_controller.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'app_segmented_control.dart';
import 'app_modal.dart';
import 'count_stepper.dart';
import 'fix_chip_count_sheet.dart';
import 'structure_builder_options.dart';
import 'structure_feasibility_card.dart';

/// The one stack-first structure flow (WP2), used by the quick game, the
/// event's Create structure and the free blind generator.
///
///   1. inputs      — players, time, type, pace, format, rebuys, add-on, ante,
///                    on-time bonus, chips
///   2. stack       — the starting stack, its depth and the bank check, BEFORE
///                    any level is shown; the host approves or edits it
///   3. structure   — every level, editable in place; pinned rows can be
///                    "recalculated around"; the rebuy close can be moved
///
/// The widget holds no engine logic: every figure comes from
/// [StructureBuilderController.structure].
class StructureBuilder extends StatelessWidget {
  const StructureBuilder({
    super.key,
    required this.controller,
    required this.confirmLabel,
    required this.onConfirm,
    this.onSavePreset,
    this.onPersist,
    this.onEditChips,
    this.onChipCountFixed,
    this.chipSetChoices,
    this.chipSetKey,
    this.onChipSetChosen,
    this.maxPlayers = 100,
    this.playersHint,
    this.extraActions,
    this.error,
    this.busy = false,
  });

  final StructureBuilderController controller;
  final String confirmLabel;

  /// The host pressed the final button on a night that can be dealt.
  final void Function(TournamentStructure structure) onConfirm;

  /// Saves every current builder choice as one reusable game preference.
  final VoidCallback? onSavePreset;

  /// Event mode saves progress (stack, pins, rebuy close) so it survives
  /// leaving the screen. Called after each committed change.
  final VoidCallback? onPersist;

  /// Opens the host's chip set editor (quick / event).
  final VoidCallback? onEditChips;

  /// Called after the host corrected the chip count on the stack step
  /// ("Fix count"), so the screen can offer to save the set. The button is
  /// shown for a real chip case (quick / event), never for the free tool.
  final void Function(List<ChipColor> counts)? onChipCountFixed;

  /// The free tool lets the host pick a box; the app modes use their own case.
  final Map<String, List<ChipColor>>? chipSetChoices;
  final String? chipSetKey;
  final void Function(String key)? onChipSetChosen;

  final int maxPlayers;
  final String? playersHint;

  /// Extra buttons under the confirm button on the structure step (Share).
  final Widget Function(BuildContext context, TournamentStructure s)?
  extraActions;

  final String? error;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => switch (controller.step) {
        BuilderStep.inputs => _InputsStep(builder: this),
        BuilderStep.stack => _StackStep(builder: this),
        BuilderStep.structure => _StructureStep(builder: this),
      },
    );
  }
}

// ─── Shared bits ───────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child, this.hint});

  final String label;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w700),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

String _clock(int minutes) {
  final m = minutes % (24 * 60);
  return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
}

String _hoursLabel(double h) {
  final whole = h.truncate();
  return h == whole ? '${whole}h' : '${whole}h 30m';
}

// ─── 1. Inputs ─────────────────────────────────────────────────────────────

class _InputsStep extends StatelessWidget {
  const _InputsStep({required this.builder});

  final StructureBuilder builder;

  @override
  Widget build(BuildContext context) {
    final c = builder.controller;
    final isCustom = c.customDepth;
    return Column(
      key: const Key('builder-step-inputs'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          label: 'Players',
          hint: builder.playersHint,
          child: CountStepper(
            value: c.players,
            min: 2,
            max: builder.maxPlayers,
            suffix: 'players',
            semanticLabel: 'Players',
            onChanged: c.setPlayers,
          ),
        ),
        _Section(
          label: 'How long',
          hint: 'Finishes around ${_clock(c.finishMinutes)}',
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const Key('hours-minus'),
                    tooltip: 'Shorter',
                    onPressed: () => c.setDurationHours(c.durationHours - 0.5),
                    icon: const Icon(Icons.remove),
                  ),
                  Text(
                    _hoursLabel(c.durationHours),
                    key: const Key('hours-value'),
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    key: const Key('hours-plus'),
                    tooltip: 'Longer',
                    onPressed: () => c.setDurationHours(c.durationHours + 0.5),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.secondary,
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: c.finishMinutes ~/ 60,
                      minute: c.finishMinutes % 60,
                    ),
                  );
                  if (picked != null) {
                    c.setFinishMinutes(picked.hour * 60 + picked.minute);
                  }
                },
                child: const Text('Set finish time'),
              ),
            ],
          ),
        ),
        _Section(
          label: 'Tournament type',
          hint: isCustom
              ? 'Custom depth: ${c.depthBB} big blinds'
              : '${c.depthBB} big blinds deep',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSegmentedControl<String>(
                values: const ['turbo', 'normal', 'deep', 'custom'],
                selected: isCustom ? 'custom' : c.type!.name,
                labels: const {
                  'turbo': 'Turbo',
                  'normal': 'Normal',
                  'deep': 'Deep',
                  'custom': 'Custom',
                },
                onSelected: (v) {
                  if (v == 'custom') {
                    c.useCustomDepth();
                  } else {
                    c.setType(TournamentType.values.byName(v));
                  }
                },
              ),
              if (isCustom) ...[
                const SizedBox(height: AppSpacing.sm),
                CountStepper(
                  value: c.depthBB,
                  min: kCustomDepthMin,
                  max: kCustomDepthMax,
                  step: kCustomDepthStep,
                  suffix: 'BB',
                  semanticLabel: 'Custom depth',
                  onChanged: c.setCustomDepth,
                ),
              ],
            ],
          ),
        ),
        _Section(
          label: 'Pace',
          hint: 'Minutes per level',
          child: AppSegmentedControl<int>(
            values: kLevelMinuteChoices,
            selected: kLevelMinuteChoices.contains(c.levelMins)
                ? c.levelMins
                : kLevelMinuteChoices[1],
            labels: {for (final m in kLevelMinuteChoices) m: '$m min'},
            onSelected: c.setLevelMins,
          ),
        ),
        _Section(
          label: 'Format',
          child: AppSegmentedControl<TournamentFormat>(
            values: const [
              TournamentFormat.freezeOut,
              TournamentFormat.rebuy,
              TournamentFormat.reEntry,
            ],
            selected: c.format,
            labels: const {
              TournamentFormat.freezeOut: 'Freeze-out',
              TournamentFormat.rebuy: 'Rebuy',
              TournamentFormat.reEntry: 'Re-entry',
            },
            onSelected: c.setFormat,
          ),
        ),
        if (c.format == TournamentFormat.rebuy)
          _Section(
            label: 'Rebuys',
            hint:
                StructureBuilderController.suggestRebuyLimit(c.players) == null
                ? 'Suggested for ${c.players} players: unlimited'
                : 'Suggested for ${c.players} players: limited to '
                      '${StructureBuilderController.suggestRebuyLimit(c.players)} each',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSegmentedControl<bool>(
                  values: const [false, true],
                  selected: c.limited,
                  labels: const {false: 'Unlimited', true: 'Limited'},
                  onSelected: (limited) => c.setRebuyLimit(
                    limited
                        ? (StructureBuilderController.suggestRebuyLimit(
                                c.players,
                              ) ??
                              2)
                        : null,
                  ),
                ),
                if (c.limited) ...[
                  const SizedBox(height: AppSpacing.sm),
                  CountStepper(
                    value: c.rebuyLimit!,
                    min: 1,
                    max: 5,
                    suffix: 'rebuys each',
                    semanticLabel: 'Rebuys each',
                    onChanged: c.setRebuyLimit,
                  ),
                ],
              ],
            ),
          ),
        if (c.rebuyNight)
          _Section(
            label: 'Add-on',
            child: AppSegmentedControl<bool>(
              values: const [true, false],
              selected: c.addOn,
              labels: const {true: 'Yes', false: 'No'},
              onSelected: c.setAddOn,
            ),
          ),
        _Section(
          label: 'Ante',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSegmentedControl<bool>(
                values: const [true, false],
                selected: c.anteEnabled,
                labels: const {true: 'Yes', false: 'No'},
                onSelected: c.setAnteEnabled,
              ),
              if (c.anteEnabled) ...[
                const SizedBox(height: AppSpacing.sm),
                AppSegmentedControl<AnteStyle>(
                  values: const [AnteStyle.bigBlind, AnteStyle.individual],
                  selected: c.anteStyle,
                  labels: const {
                    AnteStyle.bigBlind: 'Big blind',
                    AnteStyle.individual: 'Individual',
                  },
                  onSelected: c.setAnteStyle,
                ),
              ],
            ],
          ),
        ),
        _Section(
          label: 'On-time bonus',
          hint: 'Extra chips for players who arrive on time',
          child: Row(
            children: [
              CountStepper(
                value: c.bonusPct,
                min: 0,
                max: 50,
                step: 5,
                suffix: '%',
                semanticLabel: 'On-time bonus',
                onChanged: c.setBonusPct,
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                key: const Key('bonus-chips'),
                c.bonusPct == 0
                    ? 'off'
                    : '= +${Formatters.chips(c.bonusChips)} chips',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        _Section(
          label: 'Chips',
          child: _ChipsRow(builder: builder),
        ),
        if (c.mode == BuilderMode.quick) BuilderNamesSection(controller: c),
        BuilderMoreOptions(controller: c),
        if (builder.error != null) ...[
          Text(
            builder.error!,
            style: AppTypography.bodySm.copyWith(color: AppColors.destructive),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (builder.onSavePreset != null) ...[
          AppButton(
            fullWidth: true,
            variant: AppButtonVariant.secondary,
            onPressed: builder.onSavePreset,
            child: const Text('Save as preset'),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        AppButton(
          key: const Key('builder-next'),
          fullWidth: true,
          onPressed: c.continueToStack,
          child: const Text('Next: starting stack'),
        ),
      ],
    );
  }
}

class _ChipsRow extends StatelessWidget {
  const _ChipsRow({required this.builder});

  final StructureBuilder builder;

  @override
  Widget build(BuildContext context) {
    final c = builder.controller;
    final choices = builder.chipSetChoices;
    if (choices != null) {
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final k in choices.keys)
            ChoiceChip(
              key: Key('chipset-$k'),
              label: Text(k),
              selected: k == (builder.chipSetKey ?? choices.keys.first),
              onSelected: (_) {
                builder.onChipSetChosen?.call(k);
                c.setChipSet(choices[k]!);
              },
            ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: Text(
            c.chipSetName.isEmpty ? 'Your chip set' : c.chipSetName,
            style: AppTypography.bodySm,
          ),
        ),
        if (builder.onEditChips != null)
          AppButton(
            size: AppButtonSize.sm,
            variant: AppButtonVariant.secondary,
            onPressed: builder.onEditChips,
            child: const Text('Edit chips'),
          ),
      ],
    );
  }
}

// ─── 2. Stack ──────────────────────────────────────────────────────────────

class _StackStep extends StatefulWidget {
  const _StackStep({required this.builder});

  final StructureBuilder builder;

  @override
  State<_StackStep> createState() => _StackStepState();
}

class _StackStepState extends State<_StackStep> {
  final _field = TextEditingController();
  int? _shown;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _commit(StructureBuilderController c, String text) {
    final v = int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (v != null && v > 0 && v != c.structure.startingStack) {
      c.setStack(v);
      widget.builder.onPersist?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.builder;
    final c = b.controller;
    final s = c.structure;
    if (_shown != s.startingStack) {
      _shown = s.startingStack;
      _field.text = '${s.startingStack}';
    }
    final depth = c.stackDepthBB;
    final unit = c.roundUnit;
    final first = s.levels.isNotEmpty ? s.levels.first : null;
    return Column(
      key: const Key('builder-step-stack'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Starting stack',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${Formatters.chips(s.startingStack)} chips',
                key: const Key('stack-value'),
                style: AppTypography.display(
                  size: AppFontSizes.xxxl,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                depth == null
                    ? ''
                    : '${depth.round()} big blinds deep'
                          '${first == null ? '' : ' · opening ${first.sb}/${first.bb}'}',
                key: const Key('stack-depth'),
                style: AppTypography.bodySm,
              ),
              if (s.chipPlan.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Per player',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                Text(
                  [
                    for (final e in s.chipPlan)
                      if (e.count > 0) '${e.count} × ${e.value}',
                  ].join('  ·  '),
                  key: const Key('stack-chips'),
                  style: AppTypography.bodySm,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                s.bankOk
                    ? 'Your chips cover this night.'
                    : 'Your chips fall short for this night.',
                key: const Key('stack-bank'),
                style: AppTypography.bodySm.copyWith(
                  color: s.bankOk ? AppColors.success : AppColors.destructive,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        StructureFeasibilityCard(
          structure: s,
          players: c.players,
          onEditChips: b.onEditChips,
          shallowFixes: c.shallowFixes,
          onApplyShallowFix: (fix) {
            c.applyShallowFix(fix);
            // The stack step stays; the stack field follows the new figure.
          },
        ),
        if (s.isBlocked || s.isShallow || !s.fits)
          const SizedBox(height: AppSpacing.md),
        if (!c.syntheticBank &&
            b.chipSetChoices == null &&
            c.chipSet.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('fix-count'),
              onPressed: () => showAppModal(
                context: context,
                title: 'Fix the count',
                maxWidth: 420,
                child: FixChipCountSheet(
                  chips: c.chipSet,
                  onApply: (counts) {
                    c.setChipSet(counts);
                    Navigator.of(context).pop();
                    b.onChipCountFixed?.call(counts);
                    b.onPersist?.call();
                  },
                ),
              ),
              child: const Text('Fix chip count'),
            ),
          ),
        Text(
          'Change the stack',
          style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            IconButton(
              key: const Key('stack-minus'),
              tooltip: 'Smaller stack',
              onPressed: () {
                c.setStack(
                  (s.startingStack - unit).clamp(unit, 100000000).toInt(),
                );
                b.onPersist?.call();
              },
              icon: const Icon(Icons.remove),
            ),
            Expanded(
              child: TextField(
                key: const Key('stack-field'),
                controller: _field,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                onSubmitted: (t) => _commit(c, t),
                decoration: InputDecoration(
                  helperText: 'Steps of ${Formatters.chips(unit)}',
                ),
              ),
            ),
            IconButton(
              key: const Key('stack-plus'),
              tooltip: 'Bigger stack',
              onPressed: () {
                c.setStack(s.startingStack + unit);
                b.onPersist?.call();
              },
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        if (c.forceStack != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('stack-reset'),
              onPressed: () {
                c.clearForcedStack();
                b.onPersist?.call();
              },
              child: const Text('Use the suggested stack'),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          key: const Key('approve-stack'),
          fullWidth: true,
          onPressed: s.isBlocked
              ? null
              : () {
                  _commit(c, _field.text);
                  if (c.approveStack()) b.onPersist?.call();
                },
          child: const Text('Approve stack'),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          fullWidth: true,
          variant: AppButtonVariant.secondary,
          onPressed: () => c.goTo(BuilderStep.inputs),
          child: const Text('Back to the setup'),
        ),
      ],
    );
  }
}

// ─── 3. Structure ──────────────────────────────────────────────────────────

class _StructureStep extends StatefulWidget {
  const _StructureStep({required this.builder});

  final StructureBuilder builder;

  @override
  State<_StructureStep> createState() => _StructureStepState();
}

class _StructureStepState extends State<_StructureStep> {
  int? _editing;
  final _sb = TextEditingController();
  final _bb = TextEditingController();
  final _mins = TextEditingController();

  @override
  void dispose() {
    _sb.dispose();
    _bb.dispose();
    _mins.dispose();
    super.dispose();
  }

  void _startEdit(BlindLevel l) {
    setState(() {
      _editing = l.level;
      _sb.text = '${l.sb}';
      _bb.text = '${l.bb}';
      _mins.text = '${l.durationMins}';
    });
  }

  void _saveEdit() {
    final c = widget.builder.controller;
    final level = _editing!;
    final err = c.editLevel(
      level,
      sb: int.tryParse(_sb.text) ?? 0,
      bb: int.tryParse(_bb.text) ?? 0,
      mins: int.tryParse(_mins.text) ?? 0,
    );
    if (err == null) {
      setState(() => _editing = null);
      widget.builder.onPersist?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.builder;
    final c = b.controller;
    final s = c.structure;
    final levels = c.levels;
    final planned = s.effectivePlannedLevels;
    final close = c.rebuyNight ? c.rebuyCloseLevel : 0;
    return Column(
      key: const Key('builder-step-structure'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${Formatters.chips(s.startingStack)} chips · '
                      '${s.levelDuration}-minute levels',
                    ),
                    Text(
                      '$planned levels · about '
                      '${Formatters.duration(s.expectedFinishMins)}',
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const Key('change-stack'),
                onPressed: () => c.goTo(BuilderStep.stack),
                child: const Text('Change stack'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        StructureFeasibilityCard(
          structure: s,
          players: c.players,
          onEditChips: b.onEditChips,
          shallowFixes: c.shallowFixes,
          onApplyShallowFix: c.applyShallowFix,
        ),
        if (c.rebuyNight && close > 0) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              c.freshStackLabel ?? '',
              key: const Key('fresh-stack'),
              style: AppTypography.bodySm.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        for (final l in levels) ...[
          _LevelRow(
            level: l,
            pinned: c.isPinned(l.level),
            editing: _editing == l.level,
            isCloseRow: c.rebuyNight && l.level == close,
            canMoveClose: c.rebuyNight && l.level >= 2 && l.level < planned,
            sb: _sb,
            bb: _bb,
            mins: _mins,
            error: _editing == l.level ? c.pinError : null,
            onEdit: () => _startEdit(l),
            onCancel: () => setState(() {
              _editing = null;
              c.pinError = null;
            }),
            onSave: _saveEdit,
            onUnpin: () {
              c.unpin(l.level);
              b.onPersist?.call();
            },
            onRecalc: () {
              c.recalculateAround();
              b.onPersist?.call();
            },
            onCloseHere: () {
              c.setRebuyClose(l.level);
              b.onPersist?.call();
            },
          ),
          for (final br in s.breaks)
            if (br.afterLevel == l.level && br.durationMins > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  '— Break · ${br.durationMins} min'
                  '${c.addOn && c.rebuyNight && br.afterLevel == close ? ' · add-on' : ''} —',
                  key: Key('break-after-${l.level}'),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
        ],
        if (s.warnings.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          for (final w in s.warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                '• $w',
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
        ],
        if (b.error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            b.error!,
            style: AppTypography.bodySm.copyWith(color: AppColors.destructive),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          key: const Key('builder-confirm'),
          fullWidth: true,
          onPressed: (s.isBlocked || b.busy)
              ? null
              : () => b.onConfirm(c.finalStructure()),
          child: Text(b.confirmLabel),
        ),
        if (b.extraActions != null) ...[
          const SizedBox(height: AppSpacing.sm),
          b.extraActions!(context, s),
        ],
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          fullWidth: true,
          variant: AppButtonVariant.secondary,
          onPressed: () => c.goTo(BuilderStep.stack),
          child: const Text('Back to the stack'),
        ),
      ],
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.level,
    required this.pinned,
    required this.editing,
    required this.isCloseRow,
    required this.canMoveClose,
    required this.sb,
    required this.bb,
    required this.mins,
    required this.error,
    required this.onEdit,
    required this.onCancel,
    required this.onSave,
    required this.onUnpin,
    required this.onRecalc,
    required this.onCloseHere,
  });

  final BlindLevel level;
  final bool pinned;
  final bool editing;
  final bool isCloseRow;
  final bool canMoveClose;
  final TextEditingController sb;
  final TextEditingController bb;
  final TextEditingController mins;
  final String? error;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final VoidCallback onUnpin;
  final VoidCallback onRecalc;
  final VoidCallback onCloseHere;

  @override
  Widget build(BuildContext context) {
    final n = level.level;
    Widget numberField(Key key, String label, TextEditingController c) =>
        SizedBox(
          width: 84,
          child: TextField(
            key: key,
            controller: c,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: label, isDense: true),
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Container(
        key: Key('level-row-$n'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: pinned ? AppColors.primary.withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isCloseRow ? AppColors.primary : AppColors.borderSubtle,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (editing)
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'L$n',
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  numberField(Key('edit-sb-$n'), 'SB', sb),
                  numberField(Key('edit-bb-$n'), 'BB', bb),
                  numberField(Key('edit-mins-$n'), 'Minutes', mins),
                  TextButton(
                    key: Key('save-level-$n'),
                    onPressed: onSave,
                    child: const Text('Save'),
                  ),
                  TextButton(onPressed: onCancel, child: const Text('Cancel')),
                ],
              )
            else
              Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      'L$n',
                      style: AppTypography.bodySm.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${Formatters.chips(level.sb)} / ${Formatters.chips(level.bb)}'
                      '${level.ante != null ? ' · ante ${Formatters.chips(level.ante!)}' : ''}'
                      ' · ${level.durationMins} min',
                      key: Key('level-text-$n'),
                      style: AppTypography.bodySm,
                    ),
                  ),
                  if (pinned) ...[
                    Icon(
                      Icons.push_pin,
                      size: 16,
                      color: AppColors.primary,
                      semanticLabel: 'Pinned',
                    ),
                    IconButton(
                      key: Key('recalc-around-$n'),
                      tooltip: 'Recalculate around this',
                      onPressed: onRecalc,
                      icon: const Icon(Icons.calculate_outlined),
                    ),
                    IconButton(
                      key: Key('unpin-$n'),
                      tooltip: 'Let the engine choose this level',
                      onPressed: onUnpin,
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                  IconButton(
                    key: Key('edit-level-$n'),
                    tooltip: 'Edit level $n',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                ],
              ),
            if (error != null)
              Text(
                error!,
                key: Key('level-error-$n'),
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.destructive,
                ),
              ),
            if (pinned && !editing)
              Text(
                'Recalculate around this',
                key: Key('recalc-label-$n'),
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            if (isCloseRow)
              Text(
                'Rebuys close after this level',
                key: const Key('close-marker'),
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              )
            else if (canMoveClose && !editing)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: Key('close-here-$n'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onCloseHere,
                  child: const Text(
                    'Rebuys close after this level',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
