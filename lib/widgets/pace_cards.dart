import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../models/tournament.dart';
import '../utils/tournament_engine.dart';
import 'app_button.dart';

/// §F1.3 `paceOptions` rendered as C1 step 4's pace cards.
///
/// Each card carries what the spec says the host needs to choose on: the
/// opening blind, the starting depth, how many levels of what length, and when
/// the night would actually finish. §B3 allows these three to sit side by side
/// ("the 3-up pace cards where each card is short"); below a phone width they
/// stack.
///
/// Two behaviours here are the specification being deliberate, not the UI
/// being cautious:
///
///  * **Turbo is never recommended** (§F1.3). It is always offered — it is the
///    escape when nothing else fits — but it never carries the badge, and the
///    host has to pick it on purpose.
///  * **Nothing is applied silently** (§E17 row 20). When no pace fits, the
///    warning replaces the recommendation and offers §F1.3's three named
///    choices; picking one is the host's action, never the engine's.
///
/// Styling uses existing tokens and `AppButton` only — the design scheme is
/// frozen (see `PROVENANCE.md` §4).
class PaceCards extends StatelessWidget {
  const PaceCards({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.onChooseLater,
    this.onDropAddOn,
  });

  final PaceOptions options;

  /// The pace currently chosen, or null while the host has chosen none.
  final PaceMode? selected;
  final ValueChanged<PaceMode> onSelected;

  /// §F1.3's `later` choice — go back and move the finish time.
  final VoidCallback? onChooseLater;

  /// §F1.3's `noAddOn` choice — re-run without the add-on.
  final VoidCallback? onDropAddOn;

  @override
  Widget build(BuildContext context) {
    if (options.options.isEmpty) return const SizedBox.shrink();

    final warning = options.warning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final stack = constraints.maxWidth < 520;
            final cards = [
              for (final o in options.options)
                _PaceCard(
                  option: o,
                  isRecommended: options.recommended == o.pace,
                  isSelected: selected == o.pace,
                  onTap: () => onSelected(o.pace),
                ),
            ];
            if (stack) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.sm),
                    cards[i],
                  ],
                ],
              );
            }
            // IntrinsicHeight, not `CrossAxisAlignment.stretch` alone: these
            // cards live inside a scroll view, where the Row's height is
            // unbounded and `stretch` asks its children to be infinitely tall.
            // Intrinsic height measures the tallest card and matches the other
            // two to it, which is also what makes a 3-up row read as one set
            // rather than three ragged boxes.
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.sm),
                    Expanded(child: cards[i]),
                  ],
                ],
              ),
            );
          },
        ),
        if (warning != null) ...[
          const SizedBox(height: AppSpacing.md),
          _PaceWarning(
            message: warning,
            choices: options.choices,
            onChooseLater: onChooseLater,
            onDropAddOn: onDropAddOn,
            onChooseTurbo: () => onSelected(PaceMode.turbo),
          ),
        ],
      ],
    );
  }
}

class _PaceCard extends StatelessWidget {
  const _PaceCard({
    required this.option,
    required this.isRecommended,
    required this.isSelected,
    required this.onTap,
  });

  final PaceOption option;
  final bool isRecommended;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // A pace the chip case cannot supply, or that runs past the window, is
    // still selectable — the host may know something the forecast does not —
    // but it says so on its face rather than looking like a clean choice.
    final problem = !option.bankOk
        ? 'Chip case too small'
        : !option.fits
            ? 'Runs ${_mins(option.overBy)} over'
            : null;

    return Material(
      color: isSelected ? AppColors.primarySoft : AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isSelected
                  ? AppColors.primarySoftBorder
                  : AppColors.borderSubtle,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      option.pace.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySm.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? AppColors.primaryText
                            : AppColors.foreground,
                      ),
                    ),
                  ),
                  if (isRecommended)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.primarySoftBorder),
                      ),
                      child: Text(
                        'SUGGESTED',
                        style: AppTypography.bodyXs.copyWith(
                          fontSize: 9,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryText,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${option.levelMinutes}-min levels',
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _Line('Start', '${option.openingSB}/${option.openingBB}'),
              _Line('Depth', '${option.startingDepthBB.round()} BB'),
              _Line('Levels', '${option.levels}'),
              _Line('Finish', _mins(option.finishMins)),
              if (problem != null) ...[
                const SizedBox(height: 6),
                Text(
                  problem,
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.warningText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _mins(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m min';
    return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.onSurfaceHint,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// §F1.3's "nothing fits" warning, with its three named choices.
class _PaceWarning extends StatelessWidget {
  const _PaceWarning({
    required this.message,
    required this.choices,
    required this.onChooseTurbo,
    this.onChooseLater,
    this.onDropAddOn,
  });

  final String message;
  final List<String> choices;
  final VoidCallback onChooseTurbo;
  final VoidCallback? onChooseLater;
  final VoidCallback? onDropAddOn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule_outlined,
                size: 18,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'No pace fits this night',
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (choices.contains('later') && onChooseLater != null)
                AppButton(
                  variant: AppButtonVariant.secondary,
                  onPressed: onChooseLater,
                  child: const Text('Finish later'),
                ),
              if (choices.contains('noAddOn') && onDropAddOn != null)
                AppButton(
                  variant: AppButtonVariant.secondary,
                  onPressed: onDropAddOn,
                  child: const Text('Drop the add-on'),
                ),
              if (choices.contains('turbo'))
                AppButton(
                  variant: AppButtonVariant.secondary,
                  onPressed: onChooseTurbo,
                  child: const Text('Play turbo'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
