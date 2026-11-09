import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/colors.dart';
import '../app/route_paths.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../providers/app_provider.dart';

/// The account-deletion flow, shared by F2 Settings (DATA section) and
/// F1 Profile.
///
/// It lives here because both screens offer the same destructive action and
/// two copies would drift: the confirm wording is specified (§F2 DATA) and the
/// re-authentication step is a security requirement, so neither is a detail a
/// screen should own privately.
///
/// Confirm copy is §F2's: "Your results stay in the groups' history as
/// 'Former member'." That sentence matters — it is the difference between a
/// user believing deletion erases them from other people's game history (it
/// does not) and understanding what actually happens.
Future<void> confirmDeleteAccount(BuildContext context, AppProvider app) async {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text('Delete account?'),
      content: Text(
        'This permanently removes your account and invalidates any live '
        'session. This cannot be undone.\n\n'
        "Your results stay in the groups' history as 'Former member'.",
        style: AppTypography.bodySm.copyWith(
          color: AppColors.mutedForeground,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            'Cancel',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        // Addendum 2 row 6 / §B1: `redDanger` is a FILL only, with white text
        // — as a text or outline colour it measures 3.23 : 1 and fails AA. The
        // confirm sheet's destructive button is where that fill belongs; the
        // row that opens it uses `redText` for its icon and label.
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.redDanger,
            foregroundColor: AppColors.white,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            'Yes, delete my account',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  String? password;
  if (app.deleteNeedsPassword) {
    if (!context.mounted) return;
    password = await _askPassword(context);
    if (password == null) return;
  }

  final error = await app.deleteAccount(password: password);
  if (error != null) {
    messenger.showSnackBar(SnackBar(content: Text(error)));
    return;
  }
  router.go(RoutePaths.landing);
}

Future<String?> _askPassword(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text('Confirm your password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'For security, please re-enter your password to delete your '
            'account.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Password'),
            onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(
            'Cancel',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.redDanger,
            foregroundColor: AppColors.white,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          child: Text(
            'Delete account',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
