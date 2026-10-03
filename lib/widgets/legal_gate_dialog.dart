import 'package:flutter/material.dart';
import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import 'app_button.dart';
import 'min_tap_target.dart';

/// Spec H4: The organiser-contribution legal gate dialog.
///
/// Shown when a host turns on the organiser contribution (or changes country setting).
/// Requires the host to check "I understand" before the "Enable" button becomes active.
Future<bool> showOrganizerLegalGateDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _OrganizerLegalGateModal(),
  );
  return confirmed ?? false;
}

class _OrganizerLegalGateModal extends StatefulWidget {
  const _OrganizerLegalGateModal();

  @override
  State<_OrganizerLegalGateModal> createState() => _OrganizerLegalGateModalState();
}

class _OrganizerLegalGateModalState extends State<_OrganizerLegalGateModal> {
  bool _understood = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Organiser contribution',
                style: AppTypography.displaySm.copyWith(
                  color: AppColors.foreground,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'You are about to keep part of the buy-ins before prizes are paid.',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '• In Portugal, playing poker for money outside a casino is already an offence (DL 422/89 art. 110); keeping part of the money can be treated as running illegal gaming (art. 108). Similar rules apply in the UK, Spain, the Netherlands, Germany, Italy, France and many US states.',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.mutedForeground,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '• Players will only see the prize pool after your contribution.',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.mutedForeground,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'This is general information, not legal advice. You are responsible for complying with the law where you play.',
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              MinTapTarget(
                child: InkWell(
                  onTap: () => setState(() => _understood = !_understood),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _understood,
                        onChanged: (v) => setState(() => _understood = v ?? false),
                        activeColor: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'I understand',
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.foreground,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    variant: AppButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(
                    variant: AppButtonVariant.primary,
                    disabled: !_understood,
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Enable'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
