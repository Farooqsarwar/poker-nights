import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../constants/app_constants.dart';
import '../app/typography.dart';

/// Modal dialog mirroring the web `Modal` component.
class AppModal extends StatelessWidget {
  const AppModal({
    super.key,
    required this.open,
    required this.onClose,
    this.title,
    required this.child,
    this.maxWidth = 448,
  });

  final bool open;
  final VoidCallback onClose;
  final String? title;
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    if (!open) return const SizedBox.shrink();
    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: AnimatedScale(
        duration: AppDurations.fast,
        scale: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 640),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.cardGlow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title!,
                            style: AppTypography.display(size: AppFontSizes.lg),
                          ),
                        ),
                        IconButton(
                          onPressed: onClose,
                          icon: Icon(
                            Icons.close,
                            color: AppColors.mutedForeground,
                            size: 20,
                          ),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Convenience wrapper for [showDialog]-based modals.
Future<void> showAppModal({
  required BuildContext context,
  required Widget child,
  String? title,
  double maxWidth = 448,
  bool barrierDismissible = true,
}) {
  return showDialog(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (context) => AppModal(
      open: true,
      onClose: () => Navigator.of(context).pop(),
      title: title,
      maxWidth: maxWidth,
      child: child,
    ),
  );
}
