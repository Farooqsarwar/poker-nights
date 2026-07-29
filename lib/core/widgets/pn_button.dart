import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PNButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool disabled;
  final bool outlined;
  final bool destructive;
  final IconData? icon;
  final double? width;
  final double? height;

  const PNButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.disabled = false,
    this.outlined = false,
    this.destructive = false,
    this.icon,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = disabled || loading;
    final theme = Theme.of(context);

    if (outlined) {
      return SizedBox(
        width: width,
        height: height ?? 56,
        child: OutlinedButton(
          onPressed: isDisabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: destructive ? AppColors.red : AppColors.secondaryAccent,
            side: BorderSide(
              color: destructive ? AppColors.red : AppColors.secondaryAccent,
              width: 2,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: loading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 10)],
                    Text(label),
                  ],
                ),
        ),
      );
    }

    final bgColor = destructive ? AppColors.red : AppColors.primary;
    final textColor = Colors.white;

    return Container(
      width: width,
      height: height ?? 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isDisabled ? theme.disabledColor.withValues(alpha: 0.15) : bgColor,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: loading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: textColor),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null)...[
                        Icon(icon, size: 20, color: isDisabled ? theme.disabledColor : textColor),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: isDisabled ? theme.disabledColor : textColor,
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

class PNSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const PNSecondaryButton({super.key, required this.label, this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    return PNButton(label: label, onPressed: onPressed, icon: icon, outlined: true);
  }
}
