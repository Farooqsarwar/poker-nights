import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../models/chat_report.dart';
import '../models/game.dart';
import '../providers/app_provider.dart';
import 'app_modal.dart';

/// Confirms, then files a report for [message] (Addendum 1 / Apple 1.2).
///
/// Shared by the group chat, the game chat sheet and anywhere else a message
/// is shown, so the wording and the "host is told" promise stay in one place.
///
/// §E10 (2) fixes the reasons a member can pick -- "offensive -> spam ->
/// other". The list is closed so the host reads the same three words whichever
/// client filed the report, and a reason is required rather than optional:
/// a report with no reason tells the host nothing they can act on, and the
/// model already has to render one either way.
Future<void> confirmReportMessage(
  BuildContext context,
  AppProvider app,
  ChatMessage message,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  var reason = '';
  final reported = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        insetPadding: appDialogInsets(ctx),
        backgroundColor: AppColors.card,
        title: const Text('Report this message?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The host of this group is told straight away and can remove '
              'the message. ${message.authorName} is not told who reported '
              'it.',
              style: AppTypography.bodySm,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Why are you reporting it?',
              style: AppTypography.bodySm.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final option in ChatReport.reasons)
              _ReasonOption(
                label: option,
                selected: reason == option,
                onTap: () => setState(() => reason = option),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          TextButton(
            // Nothing is filed until a reason is chosen, so the host never
            // receives a report that says nothing.
            onPressed: reason.isEmpty
                ? null
                : () => Navigator.of(ctx).pop(reason),
            child: Text(
              'Report',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.destructiveText,
              ),
            ),
          ),
        ],
      ),
    ),
  );
  if (reported == null || reported.isEmpty) return;
  final error = await app.reportMessage(message, reason: reported);
  messenger?.showSnackBar(
    SnackBar(
      content: Text(error ?? 'Reported. The host has been told.'),
    ),
  );
}

/// One of the closed [ChatReport.reasons], drawn as a tap row rather than a
/// Material `Radio` so it carries the app's own colours.
class _ReasonOption extends StatelessWidget {
  const _ReasonOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('reportReason-$label'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? AppColors.primary : AppColors.mutedForeground,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(label, style: AppTypography.bodySm),
          ],
        ),
      ),
    );
  }
}
