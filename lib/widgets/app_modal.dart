import 'dart:ui';

import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../constants/app_constants.dart';
import '../app/typography.dart';
import 'glass_styles.dart';

/// Modal dialog mirroring the web `Modal` component with premium glassmorphism.
///
/// Uses a layered frosted-glass surface: gradient background, inner highlight
/// stripe, primary-tinted title area, and backdrop blur. Entrance uses a
/// combined scale + fade transition with deceleration curve.
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
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 640),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: Glass.blurHeavy,
              sigmaY: Glass.blurHeavy,
            ),
            child: Container(
              decoration: Glass.glassModal(),
              child: Stack(
                children: [
                  // Inner highlight layer — top sheen for glass depth
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.18),
                            Colors.white.withValues(alpha: 0.06),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title != null)
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: AppColors.border.withValues(
                                  alpha: Glass.borderOpacity,
                                ),
                              ),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary.withValues(alpha: 0.06),
                                Colors.transparent,
                              ],
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
                              Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                child: InkWell(
                                  onTap: onClose,
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.close,
                                      color: AppColors.mutedForeground,
                                      size: 20,
                                    ),
                                  ),
                                ),
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
                ],
              ),
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
  return showGeneralDialog(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Modal',
    barrierColor: Colors.black.withValues(alpha: 0.65),
    transitionDuration: const Duration(milliseconds: 220),
    transitionBuilder: (ctx, a1, a2, widget) {
      final curved = CurvedAnimation(
        parent: a1,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          child: widget,
        ),
      );
    },
    pageBuilder: (ctx, a1, a2) => AppModal(
      open: true,
      onClose: () => Navigator.of(ctx).pop(),
      title: title,
      maxWidth: maxWidth,
      child: child,
    ),
  );
}
