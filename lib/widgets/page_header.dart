import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import 'app_back_button.dart';

/// Title block for the in-app hub screens (Members, Polls, Notifications,
/// History …), laid out as the redesign draws them:
///
///   [back tile]                      [actions]
///   Title  count                  [titleAction]
///   subtitle
///
/// With no [onBack], the [actions] move up beside the title instead of
/// leaving an empty first row.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    this.onBack,
    this.backTooltip = 'Back',
    required this.title,
    this.count,
    this.subtitle,
    this.actions,
    this.titleAction,
  });

  /// When set, renders the back tile on its own first row.
  final VoidCallback? onBack;
  final String backTooltip;
  final String title;

  /// Small muted figure after the title ("Members 12").
  final int? count;
  final String? subtitle;

  /// Top-right controls ("+ Add member", "+ Create poll").
  final List<Widget>? actions;

  /// A control aligned with the title line ("Mark all read").
  final Widget? titleAction;

  @override
  Widget build(BuildContext context) {
    final hasActions = actions != null && actions!.isNotEmpty;
    final actionRow = hasActions
        ? Row(mainAxisSize: MainAxisSize.min, children: actions!)
        : null;

    final titleLine = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: title),
                    if (count != null)
                      TextSpan(
                        text: '  $count',
                        style: AppTypography.mono(
                          size: AppFontSizes.lg,
                          weight: FontWeight.w500,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.display(
                  size: 28,
                  weight: FontWeight.w700,
                  height: 1.15,
                  letterSpacing: -0.6,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (titleAction != null) ...[
          const SizedBox(width: AppSpacing.sm),
          titleAction!,
        ],
        if (onBack == null && actionRow != null) ...[
          const SizedBox(width: AppSpacing.sm),
          actionRow,
        ],
      ],
    );

    if (onBack == null) return titleLine;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Transform.translate(
              offset: const Offset(-4, 0),
              child: AppBackButton(onTap: onBack!, tooltip: backTooltip),
            ),
            const Spacer(),
            ?actionRow,
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        titleLine,
      ],
    );
  }
}
