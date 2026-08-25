import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../constants/app_constants.dart';
import '../app/typography.dart';
import 'glass_styles.dart';

/// Tab bar mirroring the web `Tabs` component — enhanced with glassmorphism.
///
/// The active tab uses the primary accent glow; inactive tabs fade gracefully.
/// The indicator bar itself has a soft glow shadow for premium depth.
class AppTabs extends StatelessWidget {
  const AppTabs({
    super.key,
    required this.tabs,
    required this.active,
    required this.onChanged,
  });

  final List<AppTabItem> tabs;
  final String active;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: Glass.glassTabBar(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final tab in tabs)
              _TabItem(
                tab: tab,
                isActive: active == tab.id,
                onTap: () => onChanged(tab.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatefulWidget {
  const _TabItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  final AppTabItem tab;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.05)
                : _hovering
                    ? AppColors.card.withValues(alpha: 0.20)
                    : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                width: 2,
                color: isActive
                    ? AppColors.primary
                    : Colors.transparent,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isActive)
                // Glowing indicator above the text (accent dot)
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.60),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              Text(
                widget.tab.label,
                style: AppTypography.bodySm.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isActive
                      ? AppColors.primary
                      : _hovering
                          ? AppColors.foreground
                          : AppColors.mutedForeground,
                ),
              ),
              if (widget.tab.count != null) ...[
                const SizedBox(width: 6),
                AnimatedContainer(
                  duration: AppDurations.fast,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primarySoft
                        : AppColors.muted,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: isActive
                        ? Border.all(
                            color: AppColors.primary.withValues(alpha: 0.25),
                          )
                        : null,
                  ),
                  child: Text(
                    '${widget.tab.count}',
                    style: AppTypography.bodyXs.copyWith(
                      color: isActive
                          ? AppColors.primary
                          : AppColors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AppTabItem {
  const AppTabItem({required this.id, required this.label, this.count});

  final String id;
  final String label;
  final int? count;
}
