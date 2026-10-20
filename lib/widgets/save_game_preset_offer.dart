import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/colors.dart';
import '../app/route_paths.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../models/live_game.dart';
import '../models/tournament_preset.dart';
import '../providers/app_provider.dart';
import 'app_button.dart';
import 'app_modal.dart';
import 'app_text_field.dart';
import 'app_toggle.dart';

/// Names and saves one complete game preference from the shared builder.
Future<void> offerSaveGamePreset(
  BuildContext context,
  AppProvider app,
  GameSettings settings,
) async {
  final name = TextEditingController();
  var makeDefault = false;
  String? error;
  var limitReached = false;

  await showAppModal(
    context: context,
    title: 'Save as preset',
    child: StatefulBuilder(
      builder: (modalContext, setModalState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Saves the format, pace, stack, payouts and this chip set.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: name,
            autofocus: true,
            label: 'Preset name',
            placeholder: 'e.g. Friday deep stack',
            error: error,
          ),
          if (limitReached) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              fullWidth: true,
              variant: AppButtonVariant.secondary,
              onPressed: () => modalContext.push(RoutePaths.upgrade),
              child: const Text('See Premium'),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppToggle(
            value: makeDefault,
            label: 'Use as my default',
            onChanged: (value) => setModalState(() => makeDefault = value),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            fullWidth: true,
            onPressed: () {
              final label = name.text.trim();
              if (label.isEmpty) {
                setModalState(() {
                  error = 'Enter a name.';
                  limitReached = false;
                });
                return;
              }
              final preset = TournamentPreset.fromSettings(
                id: 'preset-${DateTime.now().microsecondsSinceEpoch}',
                name: label,
                settings: settings,
              );
              if (!app.savePreset(preset)) {
                setModalState(
                  () {
                    error = 'Free accounts can save up to 3 presets.';
                    limitReached = true;
                  },
                );
                return;
              }
              if (makeDefault) app.setDefaultGamePreset(preset.id);
              Navigator.of(modalContext).pop();
            },
            child: const Text('Save preset'),
          ),
        ],
      ),
    ),
  );
}
