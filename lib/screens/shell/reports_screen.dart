import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/chat_report.dart';
import '../../providers/app_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/page_header.dart';

/// Reported chat messages, for the group's host (Addendum 1 / Apple 1.2).
///
/// Reached from the Reports row on the Members screen. Each report keeps a
/// snapshot of the message, so the host can act even if the author has since
/// deleted or edited it.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final reports = app.reports;

    return AppPage(
      maxWidth: 960,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            onBack: () => context.go(RoutePaths.members),
            title: 'Reports',
            count: reports.length,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!app.isAdmin)
            _Empty(
              icon: Icons.lock_outline,
              text: 'Only the host of this group can see reports.',
            )
          else if (reports.isEmpty)
            _Empty(
              icon: Icons.flag_outlined,
              text: 'No reported messages. Members can report a message from '
                  'the chat, and it shows up here.',
            )
          else
            for (final r in reports)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _ReportCard(report: r),
              ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          IconTile(icon: icon, size: 56, tone: IconTileTone.neutral),
          const SizedBox(height: AppSpacing.md),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final ChatReport report;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppProvider>();
    final reporter = app.currentGroup.members
        .where((m) => m.id == report.reporterId)
        .firstOrNull
        ?.name;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${report.authorName} wrote',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(report.excerpt, style: AppTypography.bodySm),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Reported by ${reporter ?? 'a member'} · '
            '${Formatters.relativeTime(report.createdAt)}'
            '${report.gameId != null ? ' · game chat' : ''}',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppButton(
                size: AppButtonSize.sm,
                onPressed: () =>
                    app.resolveReport(report, removeMessage: true),
                child: const Text('Remove message'),
              ),
              AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.secondary,
                onPressed: () => app.resolveReport(report),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
