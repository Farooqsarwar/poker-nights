import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../models/live_game.dart';
import '../models/tournament.dart';
import '../services/entitlements.dart';
import '../services/payment_service.dart';
import 'app_card.dart';
import 'premium_gate.dart';

/// What the engine decided, and why (addendum §2, §3, §6).
///
/// Two tiers, and the split is not arbitrary:
///
///  * The **depth explanation is free**, always. §2 requires it outright — "if
///    the engine chooses an unusual depth, explain why in plain language" — so
///    it cannot sit behind a paywall. It was already being computed and shown
///    nowhere, which is the gap this fixes.
///  * The **rest is Premium**, as §3's "Advanced AI recommendations". Pace
///    against target, why the rebuy window landed where it did, and where the
///    chips run out are analysis, not operation, and §3's monetization
///    principle only forbids paywalling operation.
class AiInsightsPanel extends StatelessWidget {
  const AiInsightsPanel({
    super.key,
    required this.structure,
    required this.settings,
    required this.tier,
  });

  final TournamentStructure structure;
  final GameSettings settings;
  final PremiumTier tier;

  @override
  Widget build(BuildContext context) {
    final note = structure.styleNote;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (note.isNotEmpty) ...[
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Why this structure',
                        style: AppTypography.bodySm.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        note,
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        PremiumGate(
          tier: tier,
          feature: PremiumFeature.advancedAiRecommendations,
          blurb: 'See how the night is projected to run — pace against your '
              'target, why the rebuy window closes where it does, and where '
              'your chips run out.',
          child: _Analysis(structure: structure, settings: settings),
        ),
      ],
    );
  }
}

class _Analysis extends StatelessWidget {
  const _Analysis({required this.structure, required this.settings});

  final TournamentStructure structure;
  final GameSettings settings;

  @override
  Widget build(BuildContext context) {
    final rows = <({String label, String value, String? note})>[];

    // ── Pace against the target the host actually asked for. ─────────────
    final targetMins = (settings.durationHours * 60).round();
    final projected = structure.expectedFinishMins;
    if (projected > 0 && targetMins > 0) {
      final drift = projected - targetMins;
      rows.add((
        label: 'Projected finish',
        value: _hm(projected),
        note: drift.abs() <= 15
            ? 'On target (${_hm(targetMins)} asked for).'
            : drift > 0
                ? '${_hm(drift)} over the ${_hm(targetMins)} you asked for.'
                : '${_hm(-drift)} under the ${_hm(targetMins)} you asked for.',
      ));
    }

    // ── Opening depth, as a number rather than a sentence. ───────────────
    if (structure.levels.isNotEmpty && structure.levels.first.bb > 0) {
      final depth = structure.startingStack / structure.levels.first.bb;
      final style = TournamentStyle.fromBigBlinds(depth);
      rows.add((
        label: 'Opening depth',
        value: '${depth.round()} BB',
        note: '${style.label} — ${style.purpose}',
      ));
    }

    // ── Where the rebuy window landed, and whether the AI moved it. ──────
    if (settings.rebuys || settings.reEntry) {
      final chosen = structure.rebuysCloseLevel > 0
          ? structure.rebuysCloseLevel
          : settings.rebuysCloseLevel;
      rows.add((
        label: 'Rebuys close',
        value: 'Level $chosen',
        note: settings.rebuyCloseChosenByOrganizer
            ? 'Your choice — the engine left it alone.'
            : chosen == 6
                ? 'The default, and it suits this structure.'
                : 'Moved from the level 6 default to keep late-game pressure '
                    'with these blinds and this stack.',
      ));
    }

    // ── Breaks, and what they cost the playing time. ─────────────────────
    if (structure.breaks.isNotEmpty) {
      final total = structure.breaks
          .fold<int>(0, (a, b) => a + b.durationMins);
      rows.add((
        label: 'Breaks',
        value: '${structure.breaks.length} · $total min',
        note: 'Counted inside your target, not added to it — so the playing '
            'time is ${_hm(targetMins - total)}.',
      ));
    }

    // ── Colour-ups: the thing hosts forget until the table is stuck. ─────
    if (structure.colorUpInstructions.isNotEmpty) {
      rows.add((
        label: 'Colour-ups planned',
        value: '${structure.colorUpInstructions.length}',
        note: 'The chips you own cannot post every level without them.',
      ));
    }

    if (rows.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'Nothing to analyse yet — generate a structure first.',
          style: AppTypography.bodyXs.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'How this night should run',
            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm,
                ),
                child: Container(height: 1, color: AppColors.border),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rows[i].label,
                        style: AppTypography.bodyXs.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (rows[i].note != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          rows[i].note!,
                          style: AppTypography.bodyXs.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  rows[i].value,
                  style: AppTypography.monoXs.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Minutes as "3h 40" — hosts think in hours, not in 220.
  static String _hm(int mins) {
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h $m';
  }
}
