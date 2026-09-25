import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/chip_color.dart';
import '../../providers/app_provider.dart';
import '../../utils/formatters.dart';
import '../../utils/tournament_engine.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/back_nav_button.dart';
import '../../widgets/chip_token.dart';
import '../../widgets/count_stepper.dart';

enum _EditorMode { exact, quick }

enum _QuickKind { unnumbered, numbered }

class EditChipSetScreen extends StatefulWidget {
  final String? chipSetId;
  const EditChipSetScreen({super.key, this.chipSetId});

  @override
  State<EditChipSetScreen> createState() => _EditChipSetScreenState();
}

class _EditChipSetScreenState extends State<EditChipSetScreen> {
  late TextEditingController _nameController;
  final List<ChipColor> _chips = [];
  bool _initialized = false;

  _EditorMode _mode = _EditorMode.exact;
  _QuickKind _quickKind = _QuickKind.unnumbered;

  String? _nameError;
  String? _dupError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      if (widget.chipSetId != null) {
        final app = context.read<AppProvider>();
        final cs = app.savedChipSets.firstWhere(
          (c) => c.id == widget.chipSetId,
        );
        _nameController.text = cs.name;
        _chips.addAll(cs.chips);
      } else {
        _nameController.text = '';
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Set<int> get _duplicateValues {
    final seen = <int>{};
    final dups = <int>{};
    for (final c in _chips) {
      if (c.value > 0 && !seen.add(c.value)) dups.add(c.value);
    }
    return dups;
  }

  Set<String> get _duplicateColors {
    final seen = <String>{};
    final dups = <String>{};
    for (final c in _chips) {
      final colorStr = c.color.trim().toLowerCase();
      if (colorStr.isNotEmpty && !seen.add(colorStr)) dups.add(c.color.trim());
    }
    return dups;
  }

  bool get _hasEmptyChipSet =>
      _chips.isEmpty || _chips.every((c) => c.quantity <= 0);

  /// Face value of the whole physical set — every colour's printed value
  /// times how many of that colour exist. Purely informational; never fed
  /// back into validation or the blind solver.
  int get _totalValue => _chips.fold(0, (sum, c) => sum + c.value * c.quantity);

  void _addChip() {
    setState(() {
      if (_mode == _EditorMode.quick && _quickKind == _QuickKind.unnumbered) {
        _chips.add(
          const ChipColor(
            color: 'White',
            hex: 0xFFE8E4D9,
            value: 0,
            quantity: 200,
          ),
        );
        _reRecommend();
      } else {
        _chips.add(
          const ChipColor(
            color: 'White',
            hex: 0xFFE8E4D9,
            value: 1,
            quantity: 100,
          ),
        );
      }
    });
  }

  /// Applies the engine's value recommendation for unnumbered chips
  /// (checklist 10-023), ordered most-available first.
  void _reRecommend() {
    final recommended = TournamentEngine.recommendUnnumberedChipSet(_chips);
    for (var i = 0; i < _chips.length; i++) {
      _chips[i] = recommended[i];
    }
  }

  void _removeChip(int index) {
    setState(() {
      _chips.removeAt(index);
    });
  }

  void _onChipChanged(int index, ChipColor updated) {
    setState(() {
      _chips[index] = updated;
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    final app = context.read<AppProvider>();
    setState(() {
      _nameError = name.isEmpty ? 'Enter a chip set name.' : null;
      if (_duplicateValues.isNotEmpty) {
        _dupError =
            'Two colours cannot share the same value (${_duplicateValues.join(', ')}).';
      } else if (_duplicateColors.isNotEmpty) {
        _dupError =
            'Two chips cannot share the same colour name (${_duplicateColors.join(', ')}).';
      } else if (_chips.any((c) => c.value <= 0)) {
        _dupError = 'All chips must have a value greater than zero.';
      } else {
        _dupError = null;
      }
    });
    if (_nameError != null || _dupError != null) return;
    if (_hasEmptyChipSet) {
      setState(
        () => _dupError = 'Add at least one chip with quantity above zero.',
      );
      return;
    }

    // Unique name within saved sets (10-002).
    final duplicateName = app.savedChipSets.any(
      (c) =>
          c.id != widget.chipSetId &&
          c.name.toLowerCase() == name.toLowerCase(),
    );
    if (duplicateName) {
      setState(() => _nameError = 'A chip set with this name already exists.');
      return;
    }

    final id =
        widget.chipSetId ?? 'cs-${DateTime.now().millisecondsSinceEpoch}';
    app.saveChipSet(id, name, _chips);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      maxWidth: 760,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              BackNavButton(onPressed: () => context.pop(), label: 'Back'),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.chipSetId == null ? 'New Chip Set' : 'Edit Chip Set',
                  style: AppTypography.display(
                    size: 26,
                    weight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              InkWell(
                onTap: _save,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.33),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'Save',
                    style: TextStyle(
                      color: AppColors.foreground,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            label: 'Set name',
            controller: _nameController,
            placeholder: 'e.g. My Tournament Set',
            error: _nameError,
            onChanged: (_) => setState(() => _nameError = null),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: _ModeButton(
                  label: 'Exact inventory',
                  active: _mode == _EditorMode.exact,
                  onTap: () => setState(() => _mode = _EditorMode.exact),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ModeButton(
                  label: 'Quick inventory',
                  active: _mode == _EditorMode.quick,
                  onTap: () => setState(() => _mode = _EditorMode.quick),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _mode == _EditorMode.exact
                ? 'Enter the exact quantity and printed value for each colour (10.2).'
                : 'Quick setup: pick colours and rank them — Poker Night suggests values (10.3).',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          if (_mode == _EditorMode.quick) _buildQuickHeader(),

          if (_dupError != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.destructive.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.destructive.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                _dupError!,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.destructiveText,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (_mode == _EditorMode.quick && _quickKind == _QuickKind.unnumbered)
            _buildReorderableList()
          else
            _buildChipList(),
          if (_chips.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _TotalValueCard(total: _totalValue),
          ],
          const SizedBox(height: AppSpacing.md),
          // Full-width, as the F5 frame draws it. Side by side, the two
          // buttons did not fit a 320px phone.
          AppButton(
            variant: AppButtonVariant.secondary,
            fullWidth: true,
            onPressed: _addChip,
            child: const Text('+ Add denomination'),
          ),
          if (_mode == _EditorMode.quick &&
              _quickKind == _QuickKind.unnumbered &&
              _chips.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            AppButton(
              variant: AppButtonVariant.ghost,
              fullWidth: true,
              onPressed: () => setState(_reRecommend),
              child: const Text('Re-suggest values'),
            ),
          ],
          if (_mode == _EditorMode.quick && _quickKind == _QuickKind.unnumbered)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Quantities are estimates — you confirm enough physical chips exist during setup review.',
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _ModeButton(
                label: 'Unnumbered',
                active: _quickKind == _QuickKind.unnumbered,
                onTap: () => setState(() => _quickKind = _QuickKind.unnumbered),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _ModeButton(
                label: 'Numbered',
                active: _quickKind == _QuickKind.numbered,
                onTap: () => setState(() => _quickKind = _QuickKind.numbered),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (_quickKind == _QuickKind.numbered)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              'Enter the printed value for each colour. Exact quantities are optional and filled at setup.',
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChipList() {
    if (_chips.isEmpty) {
      return const _EmptyChips();
    }
    return Column(
      children: [
        for (var i = 0; i < _chips.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _ChipRow(
              key: ValueKey('row-${_chips[i].color}-$i'),
              chip: _chips[i],
              index: i,
              showQuantity:
                  !(_mode == _EditorMode.quick &&
                      _quickKind == _QuickKind.numbered),
              showDragHandle: false,
              duplicateValue: _duplicateValues.contains(_chips[i].value),
              onChanged: (c) => _onChipChanged(i, c),
              onDelete: () => _removeChip(i),
            ),
          ),
      ],
    );
  }

  Widget _buildReorderableList() {
    if (_chips.isEmpty) {
      return const _EmptyChips();
    }
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: _chips.length,
      // `onReorderItem`, not the deprecated `onReorder`: it hands back a
      // newIndex already adjusted for the item being removed at oldIndex,
      // which is what the body below assumes. Under `onReorder` the index is
      // the one *before* removal, so dragging a chip downward dropped it one
      // slot past where it was released.
      onReorder: (oldIndex, newIndex) {
        setState(() {
          final chip = _chips.removeAt(oldIndex);
          _chips.insert(newIndex, chip);
          _reRecommend();
        });
      },
      itemBuilder: (context, i) => Padding(
        key: ValueKey('reorder-${_chips[i].color}'),
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: _ChipRow(
          key: ValueKey('row-${_chips[i].color}'),
          chip: _chips[i],
          index: i,
          showQuantity: false,
          showDragHandle: true,
          duplicateValue: _duplicateValues.contains(_chips[i].value),
          onChanged: (c) => _onChipChanged(i, c),
          onDelete: () => _removeChip(i),
        ),
      ),
    );
  }
}

class _EmptyChips extends StatelessWidget {
  const _EmptyChips();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            'Add at least one colour.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Most available → least available.',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

/// Running total of the set's face value — how much money the physical
/// chips represent once every colour's value × quantity is added up.
class _TotalValueCard extends StatelessWidget {
  const _TotalValueCard({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Text(
            'Total chip value',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            Formatters.prize(total),
            style: AppTypography.mono(
              size: AppFontSizes.lg,
              weight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.bodySm.copyWith(
            color: active ? AppColors.primary : AppColors.mutedForeground,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ChipRow extends StatefulWidget {
  const _ChipRow({
    super.key,
    required this.chip,
    required this.index,
    required this.showQuantity,
    required this.showDragHandle,
    required this.duplicateValue,
    required this.onChanged,
    required this.onDelete,
  });

  final ChipColor chip;
  final int index;
  final bool showQuantity;
  final bool showDragHandle;
  final bool duplicateValue;
  final ValueChanged<ChipColor> onChanged;
  final VoidCallback onDelete;

  @override
  State<_ChipRow> createState() => _ChipRowState();
}

class _ChipRowState extends State<_ChipRow> {
  late final TextEditingController _valueController;
  bool _valueError = false;

  @override
  void initState() {
    super.initState();
    _valueController = TextEditingController(
      text: widget.chip.value.toString(),
    );
  }

  @override
  void didUpdateWidget(covariant _ChipRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chip.color != widget.chip.color ||
        oldWidget.chip.value != widget.chip.value) {
      _valueController.text = widget.chip.value.toString();
    }
    if (oldWidget.chip.color != widget.chip.color) {
      _valueError = false;
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  void _onValue(String raw) {
    final v = int.tryParse(raw.trim());
    final valid = v != null && v > 0;
    setState(() => _valueError = !valid && raw.trim().isNotEmpty);
    if (valid) {
      widget.onChanged(widget.chip.copyWith(value: v));
    } else if (raw.trim().isEmpty) {
      // Empty field — revert to previous valid value
      widget.onChanged(widget.chip.copyWith(value: widget.chip.value));
    }
    // Invalid but non-empty: don't update model, just show error
  }

  void _onQuantity(int q) =>
      widget.onChanged(widget.chip.copyWith(quantity: q));

  void _pickColor() {
    Color pickerColor = Color(widget.chip.hex);
    final nameController = TextEditingController(text: widget.chip.color);

    final dialogInsets = appDialogInsets(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: dialogInsets,
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ColorPicker(
                pickerColor: pickerColor,
                onColorChanged: (color) {
                  pickerColor = color;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(controller: nameController, label: 'Color Name'),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Got it'),
            onPressed: () {
              final hexName =
                  '#${pickerColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
              final inputName = nameController.text.trim();
              widget.onChanged(
                widget.chip.copyWith(
                  color: inputName.isEmpty ? hexName : inputName,
                  hex: pickerColor.toARGB32(),
                ),
              );
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chip = widget.chip;
    final errorColor = AppColors.destructive;
    final borderColor = widget.duplicateValue || _valueError
        ? errorColor
        : AppColors.border;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (widget.showDragHandle)
                ReorderableDragStartListener(
                  index: widget.index,
                  child: Padding(
                    padding: EdgeInsets.only(right: AppSpacing.xs),
                    child: Icon(
                      Icons.drag_handle,
                      size: 18,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
              ChipToken(
                colorName: chip.color,
                hex: chip.colorValue,
                value: chip.value,
                count: chip.quantity,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: GestureDetector(
                  onTap: _pickColor,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Color(chip.hex),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            chip.color,
                            style: AppTypography.bodySm,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove this chip colour',
                icon: Icon(Icons.delete, color: AppColors.destructiveText),
                onPressed: widget.onDelete,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 88,
                child: TextField(
                  controller: _valueController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySm,
                  decoration: InputDecoration(
                    labelText: 'Value',
                    isDense: true,
                    errorText: widget.duplicateValue
                        ? 'dup'
                        : (_valueError ? 'inv' : null),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.ring),
                    ),
                  ),
                  onChanged: _onValue,
                ),
              ),
              if (widget.showQuantity) ...[
                const SizedBox(width: AppSpacing.lg),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Quantity',
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    CountStepper(
                      value: chip.quantity,
                      min: 0,
                      max: 9999,
                      step: 5,
                      semanticLabel: '${chip.color} chip quantity',
                      onChanged: _onQuantity,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
