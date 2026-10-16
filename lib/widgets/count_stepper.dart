import 'dart:async';

import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import 'glass_styles.dart';

/// A minus / value / plus control for a small integer.
///
/// Typing a head-count into a text field is the wrong affordance for a value
/// that is almost always adjusted by one or two from a sensible default: the
/// keyboard covers the form on a phone, and a free-text field admits "2O" and
/// empty strings that then have to be validated. A stepper cannot produce an
/// invalid value at all, and the client asked for exactly this pattern.
///
/// [onChanged] is called with the clamped result; it is never called with a
/// value outside [min]..[max], and the disabled arrow is dimmed rather than
/// hidden so the limit is visible rather than mysterious.
class CountStepper extends StatefulWidget {
  const CountStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 999,
    this.step = 1,
    this.stepSizes = const [],
    this.quickSteps = const [],
    this.suffix,
    this.semanticLabel,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;
  final List<int> stepSizes;
  final List<int> quickSteps;

  /// Rendered after the number, e.g. "players".
  final String? suffix;

  final String? semanticLabel;

  @override
  State<CountStepper> createState() => _CountStepperState();
}

class _CountStepperState extends State<CountStepper> {
  late int _workingValue = widget.value;
  late int _step = widget.stepSizes.contains(widget.step)
      ? widget.step
      : (widget.stepSizes.isEmpty ? widget.step : widget.stepSizes.first);

  @override
  void didUpdateWidget(covariant CountStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    _workingValue = widget.value;
  }

  void _nudge(int delta) {
    final next = (_workingValue + delta).clamp(widget.min, widget.max);
    if (next != _workingValue) {
      _workingValue = next;
      widget.onChanged(next);
    }
  }

  Future<void> _enterNumber() async {
    final controller = TextEditingController(text: '${widget.value}');
    final next = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter number'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          selectAllOnFocus: true,
          onSubmitted: (_) =>
              Navigator.pop(context, int.tryParse(controller.text)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (next == null) return;
    _workingValue = next.clamp(widget.min, widget.max);
    widget.onChanged(_workingValue);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      value: '${widget.value}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Glass.solidTint(AppColors.secondary),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StepperButton(
                  icon: Icons.remove,
                  enabled: widget.value > widget.min,
                  onTap: () => _nudge(-_step),
                  tooltip: 'Decrease',
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 56),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: InkWell(
                      onTap: _enterNumber,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          widget.suffix == null
                              ? '${widget.value}'
                              : '${widget.value} ${widget.suffix}',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyStyle.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.foreground,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _StepperButton(
                  icon: Icons.add,
                  enabled: widget.value < widget.max,
                  onTap: () => _nudge(_step),
                  tooltip: 'Increase',
                ),
              ],
            ),
          ),
          if (widget.stepSizes.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.xs),
            for (final candidate in widget.stepSizes)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: ChoiceChip(
                  label: Text('×$candidate'),
                  selected: _step == candidate,
                  onSelected: (_) => setState(() => _step = candidate),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
          if (widget.quickSteps.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.xs),
            for (final qs in widget.quickSteps)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: InkWell(
                  onTap: () => _nudge(qs),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text(
                      '+$qs',
                      style: AppTypography.monoXs.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StepperButton extends StatefulWidget {
  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final String tooltip;

  @override
  State<_StepperButton> createState() => _StepperButtonState();
}

class _StepperButtonState extends State<_StepperButton> {
  Timer? _repeat;

  void _startRepeat() {
    if (!widget.enabled) return;
    widget.onTap();
    _repeat?.cancel();
    _repeat = Timer.periodic(
      const Duration(milliseconds: 120),
      (_) => widget.onTap(),
    );
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: Listener(
        onPointerUp: (_) => _stopRepeat(),
        onPointerCancel: (_) => _stopRepeat(),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: widget.enabled ? widget.onTap : null,
          onLongPress: widget.enabled ? _startRepeat : null,
          // 48x48 is Material's minimum touch target (Apple's is 44pt). The
          // client operates this one-handed at a poker table, often standing,
          // and Addendum §8 calls for exactly that — so take the larger of the
          // two floors rather than the smaller.
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(
              widget.icon,
              size: 20,
              color: widget.enabled
                  ? AppColors.primary
                  : AppColors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}
