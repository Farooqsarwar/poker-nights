import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/icons.dart';
import '../app/colors.dart';
import '../app/route_paths.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../providers/app_provider.dart';
import 'app_button.dart';
import 'app_modal.dart';
import 'app_text_field.dart';

/// Opens the "create group" dialog: name + icon picker, then creates the group.
Future<void> openCreateGroupDialog(BuildContext context) {
  final controller = TextEditingController();
  String selectedIconName = 'Card';
  bool isCreating = false;

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
            enabled: !isCreating,
            onSubmitted: isCreating
                ? null
                : (_) async {
                    setState(() => isCreating = true);
                    await _create(context, controller, selectedIconName, (val) => setState(() => isCreating = val));
                  },
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md,
              horizontal: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceHover.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Group icon',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final name in groupIconNames)
                      InkWell(
                        onTap: isCreating
                            ? null
                            : () => setState(() => selectedIconName = name),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: name == selectedIconName
                                ? AppColors.primarySoft
                                : AppColors.card,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: name == selectedIconName
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: name == selectedIconName ? 1.5 : 0.8,
                            ),
                            boxShadow: name == selectedIconName
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 8,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: AppColors.shadowDeep.withValues(
                                        alpha: 0.15,
                                      ),
                                      blurRadius: 2,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                          ),
                          child: Icon(
                            groupIconMap[name],
                            size: 24,
                            color: name == selectedIconName
                                ? AppColors.primary
                                : AppColors.mutedForeground,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            fullWidth: true,
            disabled: isCreating,
            onPressed: isCreating
                ? null
                : () async {
                    setState(() => isCreating = true);
                    await _create(context, controller, selectedIconName, (val) => setState(() => isCreating = val));
                  },
            child: isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Create group'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _create(
  BuildContext context,
  TextEditingController controller,
  String iconName,
  void Function(bool) setCreating,
) async {
  final name = controller.text.trim();
  if (name.isEmpty) {
    setCreating(false);
    return;
  }
  final app = context.read<AppProvider>();
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final created = await app.createGroup(name, icon: iconName);
  if (created == null) {
    setCreating(false);
    messenger.showSnackBar(const SnackBar(
      content: Text('Could not create the group. Please try again.'),
    ));
    return;
  }
  controller.dispose();
  navigator.pop();
  if (!context.mounted) return;
  context.go(RoutePaths.group);
}
