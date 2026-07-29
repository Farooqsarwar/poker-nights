import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:poker_night/features/tournament/controllers/preset_controller.dart';
import 'package:poker_night/features/tournament/models/tournament_model.dart';
import 'package:poker_night/core/theme/app_colors.dart';
import 'package:poker_night/core/widgets/pn_button.dart';
import 'package:poker_night/core/widgets/pn_card.dart';

class PresetListView extends StatefulWidget {
  final String groupId;
  final void Function(TournamentSettings)? onApply;

  const PresetListView({super.key, required this.groupId, this.onApply});

  @override
  State<PresetListView> createState() => _PresetListViewState();
}

class _PresetListViewState extends State<PresetListView> {
  late final PresetController _presetController;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<PresetController>(tag: widget.groupId)) {
      _presetController = Get.find<PresetController>(tag: widget.groupId);
    } else {
      _presetController = Get.put(PresetController(widget.groupId), tag: widget.groupId);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        title: const Text('Presets', style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
        Obx(() {
          if (_presetController.presets.isNotEmpty) {
            return IconButton(icon: const Icon(Icons.delete_sweep), onPressed: () {
              showDialog(context: context, builder: (ctx) => AlertDialog(
                title: const Text('Delete All Presets?'),
                content: const Text('This cannot be undone.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  PNButton(onPressed: () {
                    final presetsCopy = _presetController.presets.toList();
                    for (final p in presetsCopy) {
                      _presetController.deletePreset(p.id);
                    }
                    Navigator.pop(ctx);
                  }, label: 'Delete All', destructive: true, width: 120),
                ],
              ));
            });
          }
          return const SizedBox.shrink();
        }),
      ]),
      body: Obx(() {
        final presets = _presetController.presets;
        
        return presets.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.bookmark_border, size: 48, color: AppColors.textSecondary),
                const SizedBox(height: 12),
                const Text('No presets saved', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Create a tournament and save it as a preset', style: TextStyle(color: AppColors.textSecondary)),
              ]))
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: presets.length,
                    itemBuilder: (_, i) {
                      final p = presets[i];
                      final s = p.settings;
                      return PNCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          subtitle: Text(
                            '\$${s.buyIn.toInt()} buy-in, ${s.expectedPlayers} players, '
                            '${s.targetDurationHours}h, ${s.rebuysEnabled ? 'rebuy' : 'no rebuy'}',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                      trailing: PopupMenuButton<String>(onSelected: (v) {
                        if (v == 'delete') {
                          _presetController.deletePreset(p.id);
                        } else if (v == 'apply' && widget.onApply != null) {
                          widget.onApply!(s);
                          Navigator.pop(context);
                        }
                      }, itemBuilder: (_) => [
                        if (widget.onApply != null) const PopupMenuItem(value: 'apply', child: Text('Apply')),
                        const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                      ]),
                      onTap: widget.onApply != null ? () {
                        widget.onApply!(s);
                        Navigator.pop(context);
                      } : null,
                    ),
                  );
                },
              ),
            ),
          );
      }),
    );
  }
}
