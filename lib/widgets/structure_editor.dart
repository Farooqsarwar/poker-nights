import 'package:flutter/material.dart';

import '../models/tournament.dart';
import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import 'app_button.dart';
import 'app_select.dart';

/// Level durations allowed when editing the structure (checklist §12.4:
/// future levels may only be 10, 15 or 20 minutes).
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

  void _insertAfter(int index) {
    setState(() {
      final copy = _EditableLevel.copyOf(_levels[index]);
      _levels.insert(index + 1, copy);
    });
  }

  void _removeAt(int index) {
    if (_levels.length <= 1) return;
    setState(() {
      final removed = _levels.removeAt(index);
      removed.dispose();
    });
  }

  List<BlindLevel> _build() {
    final result = <BlindLevel>[];
    for (final l in _levels) {
      final bb = l.bbValue;
      result.add(BlindLevel(
        level: 0, // renumbered by the provider
        sb: l.sbValue,
        bb: bb,
        ante: l.anteOn
            ? (widget.anteStyle == AnteStyle.individual ? (bb * 0.5).round() : bb)
            : null,
        durationMins: l.durationMins,
      ));
    }
    return result;
  }

  void _apply() {
    widget.onApply(_build());
  }

  @override
  Widget build(BuildContext context) {
    final anyInvalid = _levels.any(
      (l) => l.sbValue <= 0 || l.bbValue <= 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Adjust future levels. Active and completed levels are locked.',
          style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Durations are limited to ${kAllowedLevelDurations.join(' / ')} minutes '
          'and new levels can be inserted at any point.',
          style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
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
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 48,
                child: Text('Lv ${l.level.level}', style: AppTypography.monoXs.copyWith(color: AppColors.mutedForeground)),
              ),
              Expanded(child: _MiniField(label: 'SB', controller: l.sb)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _MiniField(label: 'BB', controller: l.bb)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppSelect<String>(
                  value: '${l.durationMins}',
                  onChanged: (v) => setState(() {
                    l.durationMins = int.tryParse(v ?? '') ?? 15;
                  }),
                  items: [
                    for (final d in kAllowedLevelDurations)
                      DropdownMenuItem(value: '$d', child: Text('$d min')),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Insert level',
                icon: const Icon(Icons.add_circle_outline, size: 18, color: AppColors.primary),
                onPressed: () => _insertAfter(index),
              ),
              IconButton(
                tooltip: 'Remove level',
                icon: Icon(
                  Icons.remove_circle_outline,
                  size: 18,
                  color: _levels.length <= 1 ? AppColors.muted : AppColors.destructive,
                ),
                onPressed: _levels.length <= 1 ? null : () => _removeAt(index),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              SizedBox(width: 48, child: const SizedBox()),
              InkWell(
                onTap: () => setState(() => l.anteOn = !l.anteOn),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      l.anteOn ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 18,
                      color: l.anteOn ? AppColors.primary : AppColors.mutedForeground,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      widget.anteStyle == AnteStyle.individual
                          ? 'Ante (individual, half BB)'
                          : 'Ante (big blind ante)',
                      style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                    ),
                  ],
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
        durationMins = _snapDuration(level.durationMins) {
    sb = TextEditingController(text: '${level.sb}');
    bb = TextEditingController(text: '${level.bb}');
  }

  _EditableLevel.copyOf(_EditableLevel other)
      : level = other.level,
        durationMins = other.durationMins {
    sb = TextEditingController(text: other.sb.text);
    bb = TextEditingController(text: other.bb.text);
  }

  final BlindLevel level;
  late final TextEditingController sb;
  late final TextEditingController bb;
  int durationMins;
  late bool anteOn = level.ante != null;

  int get sbValue => int.tryParse(sb.text.trim()) ?? 0;
  int get bbValue => int.tryParse(bb.text.trim()) ?? 0;

  void dispose() {
    sb.dispose();
    bb.dispose();
  }

  static int _snapDuration(int d) {
    if (kAllowedLevelDurations.contains(d)) return d;
    int best = 15;
    var bestDiff = 1000;
    for (final candidate in kAllowedLevelDurations) {
      final diff = (candidate - d).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = candidate;
      }
    }
    return best;
  }
}

class _MiniField extends StatelessWidget {
  const _MiniField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: AppTypography.monoXs,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.ring),
        ),
      ),
    );
  }
}
