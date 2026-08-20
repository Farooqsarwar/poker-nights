import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../constants/app_constants.dart';
import '../app/typography.dart';

/// Tab bar mirroring the web `Tabs` component.
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
    return SizedBox(
      height: 46,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final tab in tabs)
              InkWell(
                onTap: () => onChanged(tab.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        width: 2,
                        color: active == tab.id
                            ? AppColors.primary
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tab.label,
                        style: AppTypography.bodySm.copyWith(
                          fontWeight: FontWeight.w500,
                          color: active == tab.id
                              ? AppColors.primary
                              : AppColors.mutedForeground,
                        ),
                      ),
                      if (tab.count != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: active == tab.id
                                ? AppColors.primarySoft
                                : AppColors.muted,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '${tab.count}',
                            style: AppTypography.bodyXs.copyWith(
                              color: active == tab.id
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
          ],
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
