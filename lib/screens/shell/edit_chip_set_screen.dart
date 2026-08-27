import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/chip_color.dart';
import '../../providers/app_provider.dart';
import '../../utils/tournament_engine.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/chip_token.dart';

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

  bool get _hasEmptyChipSet =>
      _chips.isEmpty || _chips.every((c) => c.quantity <= 0);

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
      _dupError = _duplicateValues.isNotEmpty
          ? 'Two colours cannot share the same value (${_duplicateValues.join(', ')}).'
          : null;
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
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
              Expanded(
                child: Text(
                  widget.chipSetId == null ? 'New Chip Set' : 'Edit Chip Set',
                  style: AppTypography.display(
                    size: AppFontSizes.xxl,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              AppButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            label: 'Chip Set Name',
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
                  color: AppColors.destructive,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (_mode == _EditorMode.quick && _quickKind == _QuickKind.unnumbered)
            _buildReorderableList()
          else
            _buildChipList(),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppButton(
                variant: AppButtonVariant.secondary,
                onPressed: _addChip,
                child: const Text('+ Add colour'),
              ),
              if (_mode == _EditorMode.quick &&
                  _quickKind == _QuickKind.unnumbered &&
                  _chips.isNotEmpty)
                AppButton(
                  variant: AppButtonVariant.ghost,
                  onPressed: () => setState(_reRecommend),
                  child: const Text('Re-suggest values'),
                ),
            ],
          ),
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
  late final TextEditingController _quantityController;
  bool _valueError = false;
  bool _quantityError = false;

  @override
  void initState() {
    super.initState();
    _valueController = TextEditingController(
      text: widget.chip.value.toString(),
    );
    _quantityController = TextEditingController(
      text: widget.chip.quantity.toString(),
    );
  }

  @override
  void didUpdateWidget(covariant _ChipRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chip.color != widget.chip.color ||
        oldWidget.chip.value != widget.chip.value) {
      _valueController.text = widget.chip.value.toString();
    }
    if (oldWidget.chip.color != widget.chip.color ||
        oldWidget.chip.quantity != widget.chip.quantity) {
      _quantityController.text = widget.chip.quantity.toString();
    }
    if (oldWidget.chip.color != widget.chip.color) {
      _valueError = false;
      _quantityError = false;
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    _quantityController.dispose();
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

  void _onQuantity(String raw) {
    final q = int.tryParse(raw.trim());
    final valid = q != null && q >= 0;
    setState(() => _quantityError = !valid && raw.trim().isNotEmpty);
    if (valid) {
      widget.onChanged(widget.chip.copyWith(quantity: q));
    } else if (raw.trim().isEmpty) {
      widget.onChanged(widget.chip.copyWith(quantity: 0));
    }
  }

  void _pickColor() {
    Color pickerColor = Color(widget.chip.hex);
    final nameController = TextEditingController(text: widget.chip.color);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
    final borderColor = widget.duplicateValue || _valueError || _quantityError
        ? errorColor
        : AppColors.border;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
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
                    const SizedBox(width: 8),
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
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 72,
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
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 72,
              child: TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: AppTypography.bodySm,
                decoration: InputDecoration(
                  labelText: 'Qty',
                  isDense: true,
                  errorText: _quantityError ? 'inv' : null,
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
                onChanged: _onQuantity,
              ),
            ),
          ],
          IconButton(
            icon: Icon(Icons.delete, color: AppColors.destructive),
            onPressed: widget.onDelete,
          ),
        ],
      ),
    );
  }
}
