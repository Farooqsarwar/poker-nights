import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../models/game.dart';
import '../providers/app_provider.dart';
import 'app_modal.dart';

/// Confirms, then files a report for [message] (Addendum 1 / Apple 1.2).
///
/// Shared by the group chat, the game chat sheet and anywhere else a message
/// is shown, so the wording and the "host is told" promise stay in one place.
Future<void> confirmReportMessage(
  BuildContext context,
  AppProvider app,
  ChatMessage message,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      insetPadding: appDialogInsets(ctx),
      backgroundColor: AppColors.card,
      title: const Text('Report this message?'),
      content: Text(
        'The host of this group is told straight away and can remove the '
        'message. ${message.authorName} is not told who reported it.',
        style: AppTypography.bodySm,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(
            'Cancel',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(
            'Report',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.destructiveText,
            ),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  final error = await app.reportMessage(message);
  messenger?.showSnackBar(
    SnackBar(
      content: Text(error ?? 'Reported. The host has been told.'),
    ),
  );
}
