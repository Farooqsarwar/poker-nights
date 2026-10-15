import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../models/chip_color.dart';
import '../utils/structure_builder_controller.dart';
import 'app_button.dart';
import 'app_modal.dart';
import 'chip_set_editor.dart';

/// Edits the builder's physical case in place, including arbitrary hues.
Future<void> editBuilderChipSet(
  BuildContext context,
  StructureBuilderController controller,
) async {
  var chips = List<ChipColor>.of(controller.chipSet);
  var name = controller.chipSetName;
  await showAppModal(
    context: context,
    title: 'Edit chips',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChipSetEditor(
          initial: chips,
          initialName: name,
          onChanged: (next, nextName) {
            chips = next;
            name = nextName;
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          fullWidth: true,
          onPressed: () {
            controller.setChipSet(chips, name: name);
            Navigator.of(context).pop();
          },
          child: const Text('Use these chips'),
        ),
      ],
    ),
  );
}
