import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../models/chip_color.dart';
import '../utils/tournament_engine.dart';
import 'app_button.dart';
import 'app_select.dart';
import 'chip_token.dart';
import 'count_stepper.dart';
import 'glass_styles.dart';

/// Edits the physical chips the host actually owns: which colours, what each
/// is worth, and how many there are.
///
/// User Flow section 4.5 allows chip configuration to be "prepared before the
/// event **or shortly before check-in closes**", so this has to be reachable
/// from the event page after publishing, not only from the creation wizard.
/// The wizard grew its own three-mode editor inline; this is the compact form
/// used from a modal, and it edits the same [ChipColor] list.
///
/// Values are constrained to the engine's denomination ladder so an edit
/// cannot produce a chip set the blind solver rejects, and duplicate values
/// are surfaced inline rather than at save time.
class ChipSetEditor extends StatefulWidget {
  const ChipSetEditor({
    super.key,
    required this.initial,
    required this.initialName,
    required this.onChanged,
  });

  final List<ChipColor> initial;
  final String initialName;

  /// Called with the edited set and the name to store alongside it. The name
  /// becomes 'Custom' as soon as the set stops matching the chosen preset.
  final void Function(List<ChipColor> chips, String name) onChanged;

  @override
  State<ChipSetEditor> createState() => _ChipSetEditorState();
}

class _ChipSetEditorState extends State<ChipSetEditor> {
  late List<ChipColor> _chips;
  late String _name;

  /// Denominations offered in the value dropdown. Anything outside this
  /// ladder makes the blind levels unpostable.
  static const _values = [1, 5, 10, 25, 50, 100, 250, 500, 1000, 5000];

  @override
  void initState() {
    super.initState();
    _chips = List.of(widget.initial);
    _name = widget.initialName.isEmpty ? 'Custom' : widget.initialName;
  }

  /// Whether [_chips] still equals the named preset. Once it does not, the
  /// stored name has to become 'Custom' or the review screen would keep
  /// claiming the host is running "Standard 300" with different chips.
  bool get _matchesPreset {
    final preset = TournamentEngine.chipPresets[_name];
    if (preset == null) return false;
    if (preset.length != _chips.length) return false;
    for (var i = 0; i < preset.length; i++) {
      if (preset[i] != _chips[i]) return false;
    }
    return true;
  }

  Set<int> get _duplicateValues {
    final seen = <int>{};
    final dupes = <int>{};
    for (final c in _chips) {
      if (!seen.add(c.value)) dupes.add(c.value);
    }
    return dupes;
  }

  void _emit() {
    _chips.sort((a, b) => a.value - b.value);
    widget.onChanged(List.of(_chips), _matchesPreset ? _name : 'Custom');
  }

  void _update(int index, ChipColor next) {
    setState(() {
      _chips[index] = next;
      _emit();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dupes = _duplicateValues;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSelect<String>(
          label: 'Start from a preset',
          value: TournamentEngine.presetNames.contains(_name) ? _name : null,
          hint: 'Custom set',
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _name = v;
              _chips = List.of(TournamentEngine.getPreset(v));
              _emit();
            });
          },
          items: [
            for (final n in TournamentEngine.presetNames)
              DropdownMenuItem(value: n, child: Text(n)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Set the value and how many chips of each colour you own. '
          'The stack and blind plan is rebuilt from this.',
          style: AppTypography.bodyXs.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < _chips.length; i++) ...[
          _ChipRow(
            chip: _chips[i],
            values: _values,
            duplicate: dupes.contains(_chips[i].value),
            onValue: (v) => _update(i, _chips[i].copyWith(value: v)),
            onQuantity: (q) => _update(i, _chips[i].copyWith(quantity: q)),
            // A one-colour set cannot make change at any blind, so the last
            // two colours are not removable.
            onRemove: _chips.length > 2
                ? () => setState(() {
                      _chips.removeAt(i);
                      _emit();
                    })
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (dupes.isNotEmpty) ...[
          Text(
            'Two colours share the same value. Give each colour its own '
            'denomination.',
            style: AppTypography.bodyXs.copyWith(color: AppColors.destructive),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        AppButton(
          variant: AppButtonVariant.ghost,
          onPressed: _chips.length >= _values.length
              ? null
              : () {
                  final used = _chips.map((c) => c.value).toSet();
                  final next = _values.firstWhere(
                    (v) => !used.contains(v),
                    orElse: () => _values.last,
                  );
                  setState(() {
                    _chips.add(
                      ChipColor(
                        color: 'Colour ${_chips.length + 1}',
                        hex: 0xFF7F8C8D,
                        value: next,
                        quantity: 50,
                      ),
                    );
                    _emit();
                  });
                },
          child: const Text('Add a colour'),
        ),
      ],
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.chip,
    required this.values,
    required this.duplicate,
    required this.onValue,
    required this.onQuantity,
    required this.onRemove,
  });

  final ChipColor chip;
  final List<int> values;
  final bool duplicate;
  final ValueChanged<int> onValue;
  final ValueChanged<int> onQuantity;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Glass.solidTint(AppColors.secondary),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: duplicate ? AppColors.destructive : AppColors.border,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChipToken(
            colorName: chip.color,
            hex: chip.colorValue,
            value: chip.value,
            count: chip.quantity,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppSelect<int>(
                  label: 'Value',
                  value: values.contains(chip.value) ? chip.value : null,
                  hint: '${chip.value}',
                  onChanged: (v) {
                    if (v != null) onValue(v);
                  },
                  items: [
                    for (final v in values)
                      DropdownMenuItem(value: v, child: Text('$v')),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'How many',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  CountStepper(
                    value: chip.quantity,
                    min: 1,
                    max: 500,
                    step: 5,
                    semanticLabel: '${chip.color} chips owned',
                    onChanged: onQuantity,
                  ),
                ],
              ),
              if (onRemove != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Remove ${chip.color}',
                  onPressed: onRemove,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppColors.mutedForeground,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
