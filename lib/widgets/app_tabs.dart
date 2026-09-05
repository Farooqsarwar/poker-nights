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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Container(
          width: double.infinity,
          height: isMobile ? 58 : 46, // Slightly taller on mobile to fit stacked text
          decoration: Glass.glassTabBar(),
          child: Row(
            // On mobile, expand to fill the screen evenly (no scroll).
            // On web, left-align them with padding.
            mainAxisAlignment: isMobile
                ? MainAxisAlignment.spaceEvenly
                : MainAxisAlignment.start,
            children: tabs.map((tab) {
              Widget child = _TabItem(
                tab: tab,
                isActive: active == tab.id,
                onTap: () => onChanged(tab.id),
                stacked: isMobile,
              );

              if (isMobile) {
                return Expanded(child: child);
              } else {
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: child,
                );
              }
            }).toList(),
          ),
        );
      },
    );
  }
}

class _TabItem extends StatefulWidget {
  const _TabItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
    required this.stacked,
  });

  final AppTabItem tab;
  final bool isActive;
  final VoidCallback onTap;
  final bool stacked;

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> {
  bool _hovering = false;

  List<Widget> _buildContent(bool isActive) {
    return [
      if (isActive && !widget.stacked)
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
          fontSize: widget.stacked ? 12 : 14,
          color: isActive
              ? AppColors.primary
              : _hovering
                  ? AppColors.foreground
                  : AppColors.mutedForeground,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      if (widget.tab.count != null) ...[
        SizedBox(
          width: widget.stacked ? 0 : 6,
          height: widget.stacked ? 4 : 0,
        ),
        AnimatedContainer(
          duration: AppDurations.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primarySoft : AppColors.muted,
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
              fontSize: widget.stacked ? 10 : 12,
              color: isActive ? AppColors.primary : AppColors.mutedForeground,
            ),
          ),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;
    return Semantics(
      selected: isActive,
      button: true,
      label: '${widget.tab.label}${widget.tab.count != null ? ', ${widget.tab.count}' : ''}',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppDurations.fast,
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(
              horizontal: widget.stacked ? 2 : AppSpacing.lg,
            ),
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
                  color: isActive ? AppColors.primary : Colors.transparent,
                ),
              ),
            ),
            child: widget.stacked
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _buildContent(isActive),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _buildContent(isActive),
                  ),
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
