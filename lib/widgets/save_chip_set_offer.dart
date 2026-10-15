import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../models/chip_color.dart';
import '../providers/app_provider.dart';
import 'app_button.dart';
import 'app_modal.dart';

/// A2-4, second half: after a "Fix the count" is applied, offer to keep the
/// corrected inventory as a saved chip set.
///
/// The count changes tonight's game only, which is right mid-flight but means
/// a genuine box discrepancy is lost once the tournament is over. This is the
/// offer that captures it — and only an offer: §F4's rule that nothing is
/// applied silently applies to the saved set as much as to the structure, so
/// declining leaves the saved set untouched.
void offerSaveChipSet(
  BuildContext context,
  AppProvider app,
  List<ChipColor> counts, {
  String? setName,
}) {
  final name = '${setName == null || setName.isEmpty ? 'My' : setName} set';
  showAppModal(
    context: context,
    title: 'Save these chips?',
    maxWidth: 420,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'The count you just set applies to tonight only. Save it as '
          '"$name" and the next game starts from what is really in the box.',
          style: AppTypography.bodySm.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          onPressed: () {
            app.saveChipSet(
              // A new set, never an overwrite: the host is saving what the box
              // really holds, which is a different thing from the set they
              // picked tonight.
              'cs-${DateTime.now().millisecondsSinceEpoch}',
              name,
              counts,
            );
            Navigator.of(context).pop();
          },
          child: const Text('Save as my chips'),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Just tonight'),
        ),
      ],
    ),
  );
}
