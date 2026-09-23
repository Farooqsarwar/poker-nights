import 'dart:ui';

import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../constants/app_constants.dart';
import '../app/typography.dart';
import 'coin_shuffle_animation.dart';
import 'glass_styles.dart';
import 'min_tap_target.dart';
import 'shell_insets.dart';

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
    this.maxWidth = kAppModalMaxWidth,
    this.insetPadding,
  });

  final bool open;
  final VoidCallback onClose;
  final String? title;
  final Widget child;
  final double maxWidth;

  /// Overrides the default inset. [showAppModal] passes the shell-aware value
  /// so the dialog centres over the content area rather than the window.
  final EdgeInsets? insetPadding;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    if (!open) return const SizedBox.shrink();
    return Dialog(
      insetPadding: insetPadding ?? const EdgeInsets.all(AppSpacing.lg),
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
                                child: Tooltip(
                                  message: 'Close',
                                  child: Semantics(
                                    button: true,
                                    label: title != null
                                        ? 'Close $title'
                                        : 'Close',
                                    child: InkWell(
                                      onTap: onClose,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.sm,
                                      ),
                                      child: MinTapTarget(
                                        child: Icon(
                                          Icons.close,
                                          color: AppColors.mutedForeground,
                                          size: 20,
                                        ),
                                      ),
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

/// Inset padding that centres a dialog over the CONTENT area.
///
/// A dialog lives on the root navigator and is therefore laid out against the
/// whole window. On a desktop shell route the sidebar takes the first ~265
/// logical pixels, so window-centred meant roughly 130px left of where the eye
/// expects it. Padding the left edge by the sidebar width makes the Align in
/// [Dialog] centre within what is left, which is the content area.
///
/// [context] must be the CALLER's context — it is inside the shell, whereas
/// the dialog's own context is not.
EdgeInsets appDialogInsets(BuildContext context) {
  final left = ShellInsets.read(context);
  return EdgeInsets.only(
    left: left + AppSpacing.lg,
    right: AppSpacing.lg,
    top: AppSpacing.lg,
    bottom: AppSpacing.lg,
  );
}

/// Default maximum width for any dialog in the app.
///
/// A bare [Dialog] only enforces `minWidth: 280` — there is no maximum — so a
/// dialog without an explicit cap stretches to the full window minus its inset
/// padding. On a phone that looks intentional; on a laptop it produced a card
/// well over a thousand pixels wide with a 350px animation marooned in the
/// middle of it, which reads as "the popup isn't centred".
const double kAppModalMaxWidth = 448;

/// Blocking "the app is working" popup — the coin animation plus a line of
/// text, width-capped and centred on every screen size.
///
/// Three screens hand-rolled this with a bare [Dialog] and no width
/// constraint. Sharing one implementation means the sizing is fixed in one
/// place and cannot drift apart again.
Future<void> showGeneratingModal({
  required BuildContext context,
  required String message,
}) {
  final insets = appDialogInsets(context);
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.card,
      elevation: 24,
      insetPadding: insets,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kAppModalMaxWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CoinShuffleAnimation(),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.display(size: AppFontSizes.lg),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Convenience wrapper for [showDialog]-based modals.
Future<void> showAppModal({
  required BuildContext context,
  required Widget child,
  String? title,
  double maxWidth = kAppModalMaxWidth,
  bool barrierDismissible = true,
}) {
  final insets = appDialogInsets(context);
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
      insetPadding: insets,
      child: child,
    ),
  );
}
