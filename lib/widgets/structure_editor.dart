import 'package:flutter/material.dart';

import '../models/tournament.dart';
import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../utils/formatters.dart';
import '../utils/tournament_engine.dart';
import 'app_button.dart';
import 'app_select.dart';
import 'min_tap_target.dart';

/// The level durations offered as presets when editing the structure
/// (checklist §12.4). They are no longer the only permitted values — the host
/// now sets the level length on the Parameters tab and the engine accepts
/// anything between [TournamentEngine.kMinLevelDurationMins] and
/// [TournamentEngine.kMaxLevelDurationMins] — but they remain the three
/// lengths almost everyone picks, so they stay at the top of the list.
const List<int> kAllowedLevelDurations = [10, 15, 20];

// ── Structure editor modal ────────────────────────────────────────────────────
class StructureEditor extends StatefulWidget {
  const StructureEditor({
    super.key,
    required this.structure,
    required this.currentLevel,
    required this.anteStyle,
    required this.onSpeedUp,
    required this.onSlowDown,
    required this.onApply,
  });

  final TournamentStructure structure;
  final int currentLevel;
  final AnteStyle anteStyle;
  final VoidCallback onSpeedUp;
  final VoidCallback onSlowDown;

  /// Receives the full future-level list (from the current level onward),
  /// already renumbered, so inserting/removing levels is supported.
  final void Function(List<BlindLevel> levels) onApply;

  @override
  State<StructureEditor> createState() => _StructureEditorState();
}

class _StructureEditorState extends State<StructureEditor> {
  late final List<_EditableLevel> _levels;

  @override
  void initState() {
    super.initState();
    final future = widget.structure.levels.length > widget.currentLevel
        ? widget.structure.levels.sublist(widget.currentLevel)
        : <BlindLevel>[];
    _levels = [for (final l in future) _EditableLevel(level: l)];
  }

  @override
  void dispose() {
    for (final l in _levels) {
      l.dispose();
    }
    super.dispose();
  }

  /// The presets, plus every length this structure actually uses. A host who
  /// generated 12-minute levels has to see 12 in the list — offering only the
  /// presets would make opening the editor cost them the length they chose,
  /// and would crash the dropdown, whose value must be one of its items.
  List<int> get _durationOptions => <int>{
        ...kAllowedLevelDurations,
        ..._levels.map((l) => l.durationMins),
      }.toList()
        ..sort();

  void _insertAfter(int index) {
    setState(() {
      final copy = _EditableLevel.copyOf(_levels[index]);
      _levels.insert(index + 1, copy);
    });
  }

  List<BlindLevel> _build() {
    final result = <BlindLevel>[];
    for (final l in _levels) {
      final bb = l.bbValue;
      result.add(
        BlindLevel(
          level: 0, // renumbered by the provider
          sb: l.sbValue,
          bb: bb,
          ante: l.anteOn
              ? (widget.anteStyle == AnteStyle.individual
                    ? (bb * 0.5).round()
                    : bb)
              : null,
          durationMins: l.durationMins,
        ),
      );
    }
    return result;
  }

  void _apply() {
    widget.onApply(_build());
  }

  @override
  Widget build(BuildContext context) {
    final anyInvalid = _levels.any((l) => l.sbValue <= 0 || l.bbValue <= 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Adjust future levels. Active and completed levels are locked.',
          style: AppTypography.bodySm.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Durations offer ${kAllowedLevelDurations.join(' / ')} minutes plus '
          'whatever this structure already uses, and new levels can be '
          'inserted at any point.',
          style: AppTypography.bodyXs.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < _levels.length; i++) _buildRow(i),
        if (anyInvalid) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'SB and BB must be positive.',
            style: AppTypography.bodyXs.copyWith(color: AppColors.destructive),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.danger,
                onPressed: widget.onSpeedUp,
                child: const Text('Speed up (-5m)'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.secondary,
                onPressed: widget.onSlowDown,
                child: const Text('Slow down (+5m)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          fullWidth: true,
          disabled: anyInvalid,
          onPressed: _apply,
          child: const Text('Apply & close'),
        ),
      ],
    );
  }

  Widget _buildRow(int index) {
    final l = _levels[index];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  'Lv ${l.level.level}',
                  style: AppTypography.monoXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: AppSelect<String>(
                  value: '${l.sbValue}-${l.bbValue}',
                  onChanged: (v) {
                    if (v == null) return;
                    final parts = v.split('-');
                    setState(() {
                      l.sbValue = int.parse(parts[0]);
                      l.bbValue = int.parse(parts[1]);
                    });
                  },
                  items: [
                    for (final blind in TournamentEngine.validBlindLevels)
                      DropdownMenuItem(
                        value: '${blind[0]}-${blind[1]}',
                        child: Text(
                          '${Formatters.chips(blind[0])}/${Formatters.chips(blind[1])}',
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppSelect<String>(
                  value: '${l.durationMins}',
                  onChanged: (v) => setState(() {
                    l.durationMins = int.tryParse(v ?? '') ?? 15;
                  }),
                  items: [
                    for (final d in _durationOptions)
                      DropdownMenuItem(value: '$d', child: Text('$d min')),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Insert level',
                icon: Icon(
                  Icons.add_circle_outline,
                  size: 18,
                  color: AppColors.primary,
                ),
                onPressed: () => _insertAfter(index),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              SizedBox(width: 48, child: const SizedBox()),
              Semantics(
                toggled: l.anteOn,
                child: InkWell(
                  onTap: () => setState(() => l.anteOn = !l.anteOn),
                  child: MinTapTarget(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          l.anteOn
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 18,
                          color: l.anteOn
                              ? AppColors.primary
                              : AppColors.mutedForeground,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          widget.anteStyle == AnteStyle.individual
                              ? 'Ante (individual, half BB)'
                              : 'Ante (big blind ante)',
                          style: AppTypography.bodyXs.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
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

/// Local editable copy of one future level, owning its field controllers so
/// edits survive rebuilds.
class _EditableLevel {
  _EditableLevel({required BlindLevel level})
    : level = level,
      sbValue = level.sb,
      bbValue = level.bb,
      durationMins = _snapDuration(level.durationMins);

  _EditableLevel.copyOf(_EditableLevel other)
    : level = other.level,
      sbValue = other.sbValue,
      bbValue = other.bbValue,
      durationMins = other.durationMins;

  final BlindLevel level;
  int sbValue;
  int bbValue;
  int durationMins;
  late bool anteOn = level.ante != null;

  void dispose() {}

  /// Was: snap to the nearest of 10 / 15 / 20. Now that the host sets the
  /// level length themselves, snapping would quietly rewrite a 12-minute
  /// structure to 10 the moment its owner opened the editor to change one
  /// blind. The only limits left are the engine's own.
  static int _snapDuration(int d) => d.clamp(
        TournamentEngine.kMinLevelDurationMins,
        TournamentEngine.kMaxLevelDurationMins,
      );
}
