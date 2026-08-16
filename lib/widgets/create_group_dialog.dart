import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/colors.dart';
import '../app/route_paths.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../providers/app_provider.dart';
import 'app_button.dart';
import 'app_modal.dart';
import 'app_text_field.dart';

/// Opens the "create group" dialog: name + icon, then switches to it.
/// Shared by the desktop sidebar and the mobile drawer (client feedback:
/// "+ New Group" is a first-class CTA, groups get an icon).
Future<void> openCreateGroupDialog(BuildContext context) {
  final controller = TextEditingController();
  String icon = '♠️';
  const icons = ['♠️', '♥️', '♦️', '♣️', '🃏', '🎲', '🏆', '🎰', '🍺', '🔥'];

  return showAppModal(
    context: context,
    title: 'New Group',
    child: StatefulBuilder(
      builder: (context, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(
            controller: controller,
            label: 'Group name',
            autofocus: true,
            onSubmitted: (_) => _create(context, controller, icon),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Group icon', style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final e in icons)
                InkWell(
                  onTap: () => setState(() => icon = e),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: e == icon ? AppColors.primarySoft : AppColors.surfaceHover,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: e == icon ? AppColors.primary : AppColors.border),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 20)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            fullWidth: true,
            onPressed: () => _create(context, controller, icon),
            child: const Text('Create group'),
          ),
        ],
      ),
    ),
  );
}

void _create(BuildContext context, TextEditingController controller, String icon) {
  final name = controller.text.trim();
  if (name.isEmpty) return;
  final app = context.read<AppProvider>();
  app.createGroup(name, icon: icon);
  controller.dispose();
  Navigator.of(context).pop();
  context.go(RoutePaths.group);
}
