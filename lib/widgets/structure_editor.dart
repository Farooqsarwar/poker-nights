import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/tournament.dart';
import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../utils/formatters.dart';
import '../utils/tournament_engine.dart';
import 'app_alert_banner.dart';
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
    this.readOnly = false,
  });

  /// Whether the editor is shown but cannot be changed.
  ///
  /// §C2 line 1892: `/t/:id/levels` is "host, co-host (co-host read-only for
  /// structure - D15)". A co-host may open the levels screen and read it, but
  /// D15 withholds the structure from them, so the controls are inert rather
  /// than absent -- the same screen, the same numbers, one role short of the
  /// pencil.
  final bool readOnly;

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
    if (widget.readOnly) return;
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
    if (widget.readOnly) return;
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
        if (!widget.readOnly) ...[
          if (anyInvalid) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'SB and BB must be positive.',
              style: AppTypography.bodyXs.copyWith(color: AppColors.destructiveText),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.destructive,
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
        ] else ...[
          // D15: a co-host may read the levels, not write them. Saying so
          // beats showing a live editor whose writes the rules would refuse.
          const SizedBox(height: AppSpacing.md),
          AppAlertBanner(
            type: AppAlertType.info,
            message:
                'A co-host runs the clock but cannot change the structure. '
                'Ask the host to edit levels.',
          ),
        ],
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
                  enabled: !widget.readOnly,
                  onChanged: (v) {
                    if (v == null) return;
                    final parts = v.split('-');
                    final p0 = int.parse(parts[0]);
                    final p1 = int.parse(parts[1]);
                    setState(() {
                      l.sbValue = math.min(p0, p1);
                      l.bbValue = math.max(p0, p1);
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
                  enabled: !widget.readOnly,
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
                // D15: a co-host reads the ladder, so the control is not merely
                // refused on tap -- it is not offered.
                onPressed: widget.readOnly ? null : () => _insertAfter(index),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              SizedBox(width: 48, child: const SizedBox()),
              Semantics(
                toggled: l.anteOn,
                // D15: the ante is part of the structure, so a co-host sees it
                // and cannot tap it. `enabled: false` on the Semantics node is
                // what a screen reader uses to say so, rather than announcing
                // a checkbox that silently does nothing.
                enabled: !widget.readOnly,
                child: InkWell(
                  onTap: widget.readOnly
                      ? null
                      : () => setState(() => l.anteOn = !l.anteOn),
                  child: Opacity(
                    // Same reasoning as AppSelect's disabled state: an
                    // active-looking control whose edit is thrown away is worse
                    // than a visibly inert one.
                    opacity: widget.readOnly ? 0.5 : 1,
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
