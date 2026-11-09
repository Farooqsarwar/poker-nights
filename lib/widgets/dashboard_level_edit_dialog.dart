import 'dart:math';
import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../models/live_game.dart';
import '../models/tournament.dart';
import '../utils/formatters.dart';
import 'app_button.dart';
import 'app_text_field.dart';

/// Modal dialog allowing the host to edit any dashboard level (spec T5).
/// Offers "This level only" or "Recalculate after this" with a live preview.
class DashboardLevelEditDialog extends StatefulWidget {
  const DashboardLevelEditDialog({
    super.key,
    required this.game,
    required this.level,
    required this.onApply,
    this.isPlayed = false,
  });

  final LiveGame game;
  final BlindLevel level;
  final bool isPlayed;
  final void Function({
    required int sb,
    required int bb,
    int? ante,
    required int durationMins,
    required bool recalculateAfter,
  }) onApply;

  @override
  State<DashboardLevelEditDialog> createState() =>
      _DashboardLevelEditDialogState();
}

class _DashboardLevelEditDialogState extends State<DashboardLevelEditDialog> {
  late final TextEditingController _sbCtrl;
  late final TextEditingController _bbCtrl;
  late final TextEditingController _anteCtrl;
  late int _durationMins;
  bool _recalculateAfter = true;

  @override
  void initState() {
    super.initState();
    _recalculateAfter = !widget.isPlayed;
    _sbCtrl = TextEditingController(text: widget.level.sb.toString());
    _bbCtrl = TextEditingController(text: widget.level.bb.toString());
    _anteCtrl = TextEditingController(
      text: widget.level.ante != null ? widget.level.ante.toString() : '',
    );
    _durationMins = widget.level.durationMins;
  }

  @override
  void dispose() {
    _sbCtrl.dispose();
    _bbCtrl.dispose();
    _anteCtrl.dispose();
    super.dispose();
  }

  int get _parsedSB => int.tryParse(_sbCtrl.text.trim()) ?? widget.level.sb;
  int get _parsedBB => int.tryParse(_bbCtrl.text.trim()) ?? widget.level.bb;
  int? get _parsedAnte => _anteCtrl.text.trim().isEmpty
      ? null
      : int.tryParse(_anteCtrl.text.trim());

  bool get _isValid => _parsedSB > 0 && _parsedBB > _parsedSB && _durationMins > 0;

  List<BlindLevel> _computePreview() {
    final allLevels = [...widget.game.structure.levels];
    final idx = allLevels.indexWhere((l) => l.level == widget.level.level);
    if (idx < 0) return [widget.level];

    final edited = widget.level.copyWith(
      sb: _parsedSB,
      bb: _parsedBB,
      ante: _parsedAnte,
      durationMins: _durationMins,
    );

    if (!_recalculateAfter) {
      return [edited];
    }

    final minChip = widget.game.structure.chipPlan.isNotEmpty
        ? widget.game.structure.chipPlan.first.value
        : 25;

    final preview = <BlindLevel>[edited];
    int curBB = _parsedBB;
    for (var i = idx + 1; i < min(allLevels.length, idx + 5); i++) {
      final stepMultiplier = 1.35;
      var nextBB = ((curBB * stepMultiplier) / minChip).round() * minChip;
      if (nextBB <= curBB) nextBB = curBB + minChip;
      var nextSB = nextBB ~/ 2;
      if (nextSB % minChip != 0) {
        nextSB = ((nextSB / minChip).round() * minChip).clamp(minChip, nextBB);
      }
      if (nextSB >= nextBB) nextSB = nextBB - minChip;

      int? nextAnte;
      if (_parsedAnte != null || allLevels[i].ante != null) {
        if (widget.game.settings.anteStyle == AnteStyle.individual) {
          nextAnte = (nextBB * 0.5).round();
        } else {
          nextAnte = nextBB;
        }
      }

      preview.add(
        allLevels[i].copyWith(
          sb: nextSB,
          bb: nextBB,
          ante: nextAnte,
        ),
      );
      curBB = nextBB;
    }
    return preview;
  }

  @override
  Widget build(BuildContext context) {
    final previewLevels = _computePreview();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Edit Level ${widget.level.level}',
            style: AppTypography.displaySm,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Modify blinds, ante and duration. Choose whether to recalculate following levels smoothly.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Inputs row: SB and BB
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _sbCtrl,
                  label: 'Small blind',
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppTextField(
                  controller: _bbCtrl,
                  label: 'Big blind',
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Ante and Duration
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _anteCtrl,
                  label: 'Ante (optional)',
                  hint: 'None',
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Minutes',
                      style: AppTypography.bodyXs.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    DropdownButtonFormField<int>(
                      initialValue: _durationMins,
                      dropdownColor: AppColors.card,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.secondary,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                      ),
                      items: [5, 10, 12, 15, 20, 25, 30]
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text('$m min'),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _durationMins = val);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Mode toggle: This level only vs Recalculate after this
          if (!widget.isPlayed) ...[
            Text(
              'Recalculation option',
              style: AppTypography.bodySm.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _recalculateAfter = false),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: !_recalculateAfter
                            ? AppColors.primarySoft
                            : AppColors.secondary,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: !_recalculateAfter
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'This level only',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: !_recalculateAfter
                                  ? AppColors.primaryText
                                  : AppColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Only Level ${widget.level.level} is changed',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _recalculateAfter = true),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: _recalculateAfter
                            ? AppColors.primarySoft
                            : AppColors.secondary,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: _recalculateAfter
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recalculate after this',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _recalculateAfter
                                  ? AppColors.primaryText
                                  : AppColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Subsequent levels scale smoothly',
                            style: TextStyle(
                              fontSize: 11,
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
            const SizedBox(height: AppSpacing.lg),
          ],

          // Live Preview
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Preview',
                      style: AppTypography.bodyXs.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _recalculateAfter
                          ? 'Showing upcoming steps'
                          : 'Single level update',
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final p in previewLevels)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text(
                          'Level ${p.level}:',
                          style: AppTypography.monoXs.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '${Formatters.chips(p.sb)} / ${Formatters.chips(p.bb)}',
                          style: AppTypography.monoXs,
                        ),
                        if (p.ante != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            '(Ante: ${Formatters.chips(p.ante!)})',
                            style: AppTypography.monoXs.copyWith(
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          '${p.durationMins}m',
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

          // Actions: Cancel & Apply
          Row(
            children: [
              Expanded(
                child: AppButton(
                  variant: AppButtonVariant.ghost,
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  disabled: !_isValid,
                  onPressed: () {
                    widget.onApply(
                      sb: _parsedSB,
                      bb: _parsedBB,
                      ante: _parsedAnte,
                      durationMins: _durationMins,
                      recalculateAfter: _recalculateAfter,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Apply Changes'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
