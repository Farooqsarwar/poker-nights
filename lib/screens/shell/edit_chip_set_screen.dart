import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/chip_color.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_text_field.dart';

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

  final _predefinedColors = <String, int>{
    'White': 0xFFE8E4D9,
    'Red': 0xFFC0392B,
    'Blue': 0xFF2980B9,
    'Black': 0xFF2C2C2C,
    'Green': 0xFF27AE60,
    'Purple': 0xFF8E44AD,
    'Yellow': 0xFFF1C40F,
    'Orange': 0xFFE67E22,
    'Pink': 0xFFFD79A8,
    'Brown': 0xFF834C24,
  };

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
        final cs = app.savedChipSets.firstWhere((c) => c.id == widget.chipSetId);
        _nameController.text = cs.name;
        _chips.addAll(cs.chips);
      } else {
        _nameController.text = 'New Chip Set';
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addChip() {
    setState(() {
      _chips.add(const ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 100));
    });
  }

  void _removeChip(int index) {
    setState(() {
      _chips.removeAt(index);
    });
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) return;
    if (_chips.isEmpty) return;

    final app = context.read<AppProvider>();
    final id = widget.chipSetId ?? 'cs-${DateTime.now().millisecondsSinceEpoch}';
    app.saveChipSet(id, _nameController.text.trim(), _chips);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      maxWidth: 720,
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
                  style: AppTypography.display(size: AppFontSizes.xxl, weight: FontWeight.w700),
                ),
              ),
              AppButton(
                onPressed: _save,
                child: const Text('Save'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            label: 'Chip Set Name',
            controller: _nameController,
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Chips', style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600)),
              AppButton(
                variant: AppButtonVariant.secondary,
                onPressed: _addChip,
                child: const Text('Add Chip'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _chips.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final chip = _chips[index];
              return AppCard(
                child: Row(
                  children: [
                    // Color Picker Dropdown
                    Container(
                      width: 100,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: chip.color,
                          isExpanded: true,
                          dropdownColor: AppColors.card,
                          items: _predefinedColors.entries.map((e) {
                            return DropdownMenuItem(
                              value: e.key,
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: Color(e.value),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(e.key, style: AppTypography.bodySm, overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _chips[index] = chip.copyWith(color: val, hex: _predefinedColors[val]!);
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Value Input
                    Expanded(
                      child: TextFormField(
                        initialValue: chip.value.toString(),
                        keyboardType: TextInputType.number,
                        style: AppTypography.bodySm,
                        decoration: const InputDecoration(
                          labelText: 'Value',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          final v = int.tryParse(val) ?? 0;
                          _chips[index] = chip.copyWith(value: v);
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Quantity Input
                    Expanded(
                      child: TextFormField(
                        initialValue: chip.quantity.toString(),
                        keyboardType: TextInputType.number,
                        style: AppTypography.bodySm,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          final q = int.tryParse(val) ?? 0;
                          _chips[index] = chip.copyWith(quantity: q);
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: AppColors.destructive),
                      onPressed: () => _removeChip(index),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
