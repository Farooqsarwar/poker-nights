import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/colors.dart';
import '../app/route_paths.dart';
import '../app/typography.dart';
import '../models/tournament.dart';
import '../models/tournament_format.dart';
import '../models/tournament_preset.dart';
import '../providers/app_provider.dart';
import '../utils/formatters.dart';
import '../utils/structure_builder_controller.dart';

/// #23 / rule 8: one place in Settings that shows every game default and pre-fills
/// every game (quick start, Create structure, the free tools' presets).
///
/// The preferences ARE the user's default game preset, so there is exactly one
/// object: changing the default here changes what new games start from, and
/// editing a value opens the Presets hub where that preset lives.
class GamePreferencesCard extends StatelessWidget {
  const GamePreferencesCard({super.key});

  /// Plain-language summary rows for a preset. Static so a test can read them
  /// without pumping the card.
  static List<(String, String)> rowsFor(TournamentPreset p) {
    final type = p.targetDepthBB == null
        ? null
        : TournamentTypeX.forDepth(p.targetDepthBB!);
    final typeLabel = type != null
        ? '${type.label} · ${type.depthBB} big blinds'
        : (p.targetDepthBB != null
              ? '${p.targetDepthBB} big blinds'
              : _paceTypeLabel(p.pace));
    final levelMins = p.levelDurationMins ?? (p.pace ?? PaceMode.regular).levelMinutes;
    final format = (p.format ?? TournamentFormat.freezeOut).label;
    final ante = !p.anteEnabled
        ? 'No ante'
        : (p.anteStyle == AnteStyle.individual ? 'Individual ante' : 'Big blind ante');
    final bonus = p.earlyArrivalBonusEnabled
        ? (p.earlyArrivalBonusPctOverride != null
              ? '${p.earlyArrivalBonusPctOverride}% extra chips'
              : 'On')
        : 'Off';
    final close = p.rebuys
        ? (p.rebuyCloseChosenByOrganizer
              ? 'After level ${p.rebuysCloseLevel}'
              : 'Chosen for me')
        : 'No rebuys';
    return [
      ('Tournament type', typeLabel),
      ('Format', format),
      ('Level length', '$levelMins min'),
      ('Ante', ante),
      ('Buy-in', Formatters.prize(p.buyIn)),
      ('On-time bonus', bonus),
      ('Rebuys close', close),
    ];
  }

  static String _paceTypeLabel(PaceMode? pace) => switch (pace) {
    PaceMode.turbo => 'Turbo',
    PaceMode.deep => 'Deep',
    _ => 'Normal',
  };

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final preset = app.defaultGamePreset;
    final rows = rowsFor(preset);
    final currency = app.currencySymbol.isEmpty ? 'None' : app.currencySymbol;

    return Container(
      key: const Key('game-preferences-card'),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          _row(
            context,
            title: 'Default game preset',
            value: preset.name,
            subtitle: 'Every new game starts from these values',
            keyName: 'pref-preset',
            onTap: () => _choosePreset(context, app),
          ),
          for (final r in rows)
            _row(
              context,
              title: r.$1,
              value: r.$2,
              keyName: 'pref-${r.$1}',
              onTap: () => context.push(RoutePaths.presets),
            ),
          _row(
            context,
            title: 'Currency',
            value: currency,
            keyName: 'pref-currency',
            last: true,
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String title,
    required String value,
    required String keyName,
    String? subtitle,
    VoidCallback? onTap,
    bool last = false,
  }) {
    return InkWell(
      key: Key(keyName),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(bottom: BorderSide(color: AppColors.borderSubtle)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.secondaryForeground,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 18, color: AppColors.onSurfaceHint),
            ],
          ],
        ),
      ),
    );
  }

  void _choosePreset(BuildContext context, AppProvider app) {
    final presets = app.presets;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Default game preset',
              style: AppTypography.bodyLg.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 12),
            for (final p in presets)
              ListTile(
                key: Key('pref-choose-${p.id}'),
                title: Text(
                  p.name,
                  style: TextStyle(color: AppColors.foreground),
                ),
                trailing: app.defaultGamePreset.id == p.id
                    ? Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  app.setDefaultGamePreset(p.id);
                  Navigator.of(sheet).pop();
                },
              ),
            ListTile(
              title: Text(
                'Create or edit presets',
                style: TextStyle(color: AppColors.primary),
              ),
              onTap: () {
                Navigator.of(sheet).pop();
                context.push(RoutePaths.presets);
              },
            ),
          ],
        ),
      ),
    );
  }
}
