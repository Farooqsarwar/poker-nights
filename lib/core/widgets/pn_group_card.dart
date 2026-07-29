import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/core/theme/app_colors.dart';
import 'package:poker_night/features/groups/models/group_model.dart';

class PNGroupCard extends StatelessWidget {
  final GroupModel group;
  final bool showJoinCode;
  final VoidCallback? onTap;
  final Widget? trailing;
  final int index;

  const PNGroupCard({
    super.key,
    required this.group,
    this.showJoinCode = false,
    this.onTap,
    this.trailing,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [AppColors.accent, AppColors.gold, AppColors.green, AppColors.blue, AppColors.purple, AppColors.chipOrange];
    final color = colors[index % colors.length];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap ?? () => context.push('/groups/${group.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
                    style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.people_rounded, size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${group.memberCount} member${group.memberCount == 1 ? '' : 's'}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        if (showJoinCode) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(group.joinCode, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
