import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/colors.dart';
import '../constants/app_constants.dart';
import '../app/typography.dart';

/// Code display with copy button mirroring the web `CodeDisplay` component.
class CodeDisplay extends StatefulWidget {
  const CodeDisplay({super.key, required this.code, this.label});

  final String code;
  final String? label;

  @override
  State<CodeDisplay> createState() => _CodeDisplayState();
}

class _CodeDisplayState extends State<CodeDisplay> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(AppDurations.slow, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label != null) ...[
            Text(
              widget.label!,
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Flexible(
            child: Text(
              widget.code,
              style: AppTypography.mono(
                size: AppFontSizes.xl,
                weight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 3.2,
              ),
            ),
          ),
          InkWell(
            onTap: _copy,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_copied) ...[
                    const Icon(
                      Icons.check_circle,
                      size: AppFontSizes.sm,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Text(
                    _copied ? 'Copied' : 'Copy',
                    style: AppTypography.bodyXs.copyWith(
                      color: _copied
                          ? AppColors.success
                          : AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
