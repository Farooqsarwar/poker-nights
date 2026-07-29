import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:poker_night/core/widgets/pn_button.dart';
import 'package:poker_night/features/tournament/controllers/chip_inventory_controller.dart';
import 'package:poker_night/features/tournament/models/chip_set_model.dart';
import 'package:poker_night/core/theme/app_colors.dart';
import 'package:poker_night/core/widgets/pn_card.dart';

class ChipInventoryView extends StatefulWidget {
  final String groupId;
  final String chipSetId;

  const ChipInventoryView({super.key, required this.groupId, required this.chipSetId});

  @override
  State<ChipInventoryView> createState() => _ChipInventoryViewState();
}

class _ChipInventoryViewState extends State<ChipInventoryView> {
  late final ChipInventoryController _chipInventoryController;
  final _nameController = TextEditingController();
  final _colorControllers = <String, TextEditingController>{};
  final _valueControllers = <String, TextEditingController>{};
  final _quantityControllers = <String, TextEditingController>{};
  String _mode = 'exact';
  int _nextColorIdx = 0;

  static const _presetColors = [
    {'color': 'white', 'name': 'White', 'value': '1'},
    {'color': 'red', 'name': 'Red', 'value': '5'},
    {'color': 'blue', 'name': 'Blue', 'value': '10'},
    {'color': 'green', 'name': 'Green', 'value': '25'},
    {'color': 'black', 'name': 'Black', 'value': '100'},
    {'color': 'purple', 'name': 'Purple', 'value': '500'},
    {'color': 'yellow', 'name': 'Yellow', 'value': '1000'},
    {'color': 'orange', 'name': 'Orange', 'value': '5000'},
  ];

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<ChipInventoryController>(tag: widget.groupId)) {
      _chipInventoryController = Get.find<ChipInventoryController>(tag: widget.groupId);
    } else {
      _chipInventoryController = Get.put(ChipInventoryController(widget.groupId), tag: widget.groupId);
    }
    Future.microtask(() {
      _chipInventoryController.load();
      _addColor();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final c in _colorControllers.values) {
      c.dispose();
    }
    for (final c in _valueControllers.values) {
      c.dispose();
    }
    for (final c in _quantityControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _addColor({String? color, String? value, String? quantity}) {
    final key = 'denom_$_nextColorIdx';
    _colorControllers[key] = TextEditingController(text: color ?? '');
    _valueControllers[key] = TextEditingController(text: value ?? '');
    _quantityControllers[key] = TextEditingController(text: quantity ?? '');
    _nextColorIdx++;
    if (mounted) setState(() {});
  }

  void _removeColor(String key) {
    _colorControllers[key]?.dispose();
    _valueControllers[key]?.dispose();
    _quantityControllers[key]?.dispose();
    _colorControllers.remove(key);
    _valueControllers.remove(key);
    _quantityControllers.remove(key);
    if (mounted) setState(() {});
  }

  ChipSet _buildChipSet() {
    final chips = <ChipDenomination>[];
    for (final key in _colorControllers.keys) {
      final colorName = _colorControllers[key]!.text.trim();
      final valueText = _valueControllers[key]!.text.trim();
      final qtyText = _quantityControllers[key]!.text.trim();
      if (colorName.isEmpty || valueText.isEmpty) continue;
      chips.add(ChipDenomination(
        color: colorName.toLowerCase().replaceAll(' ', '_'),
        colorName: colorName,
        value: int.tryParse(valueText) ?? 0,
        quantity: int.tryParse(qtyText) ?? 0,
      ));
    }
    return ChipSet(
      id: widget.chipSetId,
      groupId: widget.groupId,
      name: _nameController.text.trim().isEmpty ? 'Default Set' : _nameController.text.trim(),
      inventoryMode: _mode,
      chips: chips,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        title: const Text('Chip Inventory', style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Chip Set Name', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. Main Set',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.cardDark,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              Text('Inventory Mode', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'exact', label: Text('Exact'), icon: Icon(Icons.pin)),
                  ButtonSegment(value: 'quick', label: Text('Quick'), icon: Icon(Icons.tune)),
                ],
                selected: {_mode},
                onSelectionChanged: (v) => setState(() => _mode = v.first),
              ),
              const SizedBox(height: 8),
              Text(
                _mode == 'exact'
                    ? 'Enter the exact number of chips per denomination'
                    : 'Rank colors by quantity (most to least)',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Text('Denominations', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._colorControllers.keys.map((key) => _denominationRow(key)),
              const SizedBox(height: 8),
              PNButton(
                onPressed: () => _addColor(),
                icon: Icons.add,
                label: 'Add Denomination',
                outlined: true,
              ),
              const SizedBox(height: 8),
              if (_mode == 'quick')
                PNCard(
                  color: Colors.blue.withValues(alpha: 0.1),
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('In Quick mode, leave quantity as 0. The system will infer quantities from the priority order.', style: TextStyle(fontSize: 13))),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              PNButton(
                label: 'Save Chip Set',
                onPressed: () {
                  final chipSet = _buildChipSet();
                  _chipInventoryController.save(chipSet);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chip set saved')),
                  );
                  Navigator.pop(context, chipSet);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _denominationRow(String key) {
    final idx = _colorControllers.keys.toList().indexOf(key);
    return PNCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _tryMatchPreset(_colorControllers[key]!.text),
                    decoration: const InputDecoration(labelText: 'Color', isDense: true, border: OutlineInputBorder()),
                    items: _presetColors.map((pc) => DropdownMenuItem(
                      value: pc['color'],
                      child: Row(
                        children: [
                          Container(width: 16, height: 16, decoration: BoxDecoration(
                            color: _colorFromString(pc['color']!),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade300),
                          )),
                          const SizedBox(width: 8),
                          Text(pc['name']!),
                        ],
                      ),
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        final pc = _presetColors.firstWhere((c) => c['color'] == v);
                        _colorControllers[key]!.text = pc['color']!;
                        _valueControllers[key]!.text = pc['value']!;
                        if (mounted) setState(() {});
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _valueControllers[key],
                    decoration: const InputDecoration(labelText: 'Value', isDense: true, border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
                if (_mode == 'exact') ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _quantityControllers[key],
                      decoration: const InputDecoration(labelText: 'Qty', isDense: true, border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
                if (idx > 0)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                    onPressed: () => _removeColor(key),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (_mode == 'quick') ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('Priority: #${idx + 1}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  if (idx > 0) ...[
                    const Spacer(),
                    Icon(Icons.arrow_upward, size: 14, color: Colors.grey),
                    Text(' Lower = more chips', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ],
              ),
            ],
          ],
        ),
    );
  }

  String? _tryMatchPreset(String val) {
    for (final pc in _presetColors) {
      if (pc['color'] == val) return val;
    }
    return null;
  }

  Color _colorFromString(String c) {
    switch (c) {
      case 'white': return Colors.white;
      case 'red': return Colors.red;
      case 'blue': return Colors.blue;
      case 'green': return Colors.green;
      case 'black': return Colors.black;
      case 'purple': return Colors.purple;
      case 'yellow': return Colors.yellow;
      case 'orange': return Colors.orange;
      default: return Colors.grey;
    }
  }
}
