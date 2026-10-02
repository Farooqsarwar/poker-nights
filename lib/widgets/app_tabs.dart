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
        final hasCounts = tabs.any((t) => t.count != null);
        final shouldStack = hasCounts && constraints.maxWidth < 420;

        return Container(
          width: double.infinity,
          height: shouldStack ? 56 : 46,
          decoration: Glass.glassTabBar(),
          // On wide layouts tabs are left-aligned at intrinsic width, so a
          // long set (admin: Players/Eliminated/Seating/Levels/Prizes/Audit)
          // scrolled instead of overflowing. Mobile stays evenly expanded.
          child: isMobile
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: tabs.map((tab) {
                    return Expanded(
                      child: _TabItem(
                        tab: tab,
                        isActive: active == tab.id,
                        onTap: () => onChanged(tab.id),
                        stacked: shouldStack,
                      ),
                    );
                  }).toList(),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: tabs.map((tab) {
                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: _TabItem(
                          tab: tab,
                          isActive: active == tab.id,
                          onTap: () => onChanged(tab.id),
                          stacked: shouldStack,
                        ),
                      );
                    }).toList(),
                  ),
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

  /// The label, flexed in the horizontal (Row) layout so it ellipsizes inside
  /// its slot instead of overflowing it. A bare Text in a min-sized Row is
  /// measured with unbounded width, so its own maxLines/ellipsis never fires
  /// — that was the 320px overflow. In the stacked (Column) layout the width
  /// is already bounded, so no flex is used there (flex + unbounded height
  /// would throw instead).
  Widget _buildLabel(bool isActive, {required bool flexible}) {
    final label = Text(
      widget.tab.label,
      // Sized through AppTypography (AppScale.sp inside), never a raw
      // fontSize override — a raw number would bypass the scale floor.
      style: (widget.stacked ? AppTypography.bodyXs : AppTypography.bodySm)
          .copyWith(
        fontWeight: FontWeight.w500,
        // §B1: text below 24 px is `redText`, never the `red` fill token.
        // `red` measures 4.05 : 1 on the background, under the 4.5 : 1 AA
        // floor, so the active tab label was failing contrast.
        color: isActive
            ? AppColors.primaryText
            : _hovering
                ? AppColors.foreground
                : AppColors.mutedForeground,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    return flexible ? Flexible(child: label) : label;
  }

  List<Widget> _buildContent(bool isActive, {required bool flexibleLabel}) {
    return [
      if (isActive && !widget.stacked)
        // Glowing indicator beside the text (accent dot)
        Container(
          width: 5,
          height: 5,
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
      _buildLabel(isActive, flexible: flexibleLabel),
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
            // Was a raw `fontSize: 10` in stacked mode, which bypassed the
            // scale entirely. AppTypography.body(size: 10) goes through
            // AppScale.sp(), so 10 is now a floor rather than a fixed value.
            style: AppTypography.body(size: widget.stacked ? 10 : 12).copyWith(
              // Same §B1 split as the label above — the badge count is text.
              color: isActive
                  ? AppColors.primaryText
                  : AppColors.mutedForeground,
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
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            splashColor: AppColors.primarySoft,
            highlightColor: AppColors.primarySoft,
            child: AnimatedContainer(
              duration: AppDurations.fast,
              curve: Curves.easeOut,
              padding: EdgeInsets.symmetric(
                horizontal: widget.stacked ? 4 : AppSpacing.md,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.08)
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
                      children: _buildContent(isActive, flexibleLabel: false),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children:
                          _buildContent(isActive, flexibleLabel: true),
                    ),
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
