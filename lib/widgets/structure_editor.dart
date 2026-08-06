import 'package:flutter/material.dart';

import '../models/tournament.dart';
import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../providers/app_provider.dart' show LevelEdit;
import 'app_button.dart';

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
  final void Function(List<LevelEdit> edits) onApply;

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

  void _apply() {
    final edits = <LevelEdit>[];
    for (final l in _levels) {
      final bb = l.bbValue;
      edits.add((
        level: l.level.level,
        sb: l.sbValue,
        bb: bb,
        ante: l.anteOn
            ? (widget.anteStyle == AnteStyle.individual ? (bb * 0.5).round() : bb)
            : null,
        durationMins: l.durationValue,
      ));
    }
    widget.onApply(edits);
  }

  @override
  Widget build(BuildContext context) {
    final anyInvalid = _levels.any(
      (l) => l.sbValue <= 0 || l.bbValue <= 0 || l.durationValue < 1,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Adjust future levels. Active and completed levels are locked.',
          style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final l in _levels)
          Container(
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
                    Expanded(child: _MiniField(label: 'Min', controller: l.duration)),
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
          ),
        if (anyInvalid) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'SB, BB and duration must be positive.',
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
}

/// Local editable copy of one future level, owning its field controllers so
/// edits survive rebuilds.
class _EditableLevel {
  _EditableLevel({required BlindLevel level}) : level = level {
    sb = TextEditingController(text: '${level.sb}');
    bb = TextEditingController(text: '${level.bb}');
    duration = TextEditingController(text: '${level.durationMins}');
  }

  final BlindLevel level;
  late final TextEditingController sb;
  late final TextEditingController bb;
  late final TextEditingController duration;
  late bool anteOn = level.ante != null;

  int get sbValue => int.tryParse(sb.text.trim()) ?? 0;
  int get bbValue => int.tryParse(bb.text.trim()) ?? 0;
  int get durationValue => int.tryParse(duration.text.trim()) ?? 0;

  void dispose() {
    sb.dispose();
    bb.dispose();
    duration.dispose();
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
