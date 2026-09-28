import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../models/tournament.dart';
import 'app_button.dart';

/// The §F1.5 point 7 blocking card — "your chip case is too small for this
/// field" — and the §F1.3 overrun warning.
///
/// The engine has always worked both of these out and then thrown them away:
/// `feasible`, `maxPlayersSupported` and `fits` were computed, never read by
/// any screen, and (until Phase 2) not even persisted by the codec. Telling a
/// host *before* the night that their chips cannot deal a playable stack, or
/// that the structure runs past its finish time, is the single most valuable
/// thing the structure engine produces.
///
/// Styling deliberately reuses `AppColors.destructive` / `warning` and
/// `AppButton` — the design scheme is frozen, so this introduces no token and
/// no new component (see `PROVENANCE.md` §4).
class StructureFeasibilityCard extends StatelessWidget {
  const StructureFeasibilityCard({
    super.key,
    required this.structure,
    required this.players,
    this.onEditChips,
    this.onFewerRebuys,
    this.onPlayFreezeOut,
    this.onReduceField,
  });

  final TournamentStructure structure;
  final int players;

  /// §F1.5's three named buttons. A null callback hides its button, so a
  /// screen that cannot offer a route does not show a dead control.
  final VoidCallback? onEditChips;
  final VoidCallback? onFewerRebuys;
  final VoidCallback? onPlayFreezeOut;

  /// "Reduce to {n} players" — offered only when the engine worked out how
  /// many the case actually covers.
  final VoidCallback? onReduceField;

  bool get _blocked => !structure.feasible;
  bool get _overruns => structure.feasible && !structure.fits;

  @override
  Widget build(BuildContext context) {
    if (!_blocked && !_overruns) return const SizedBox.shrink();

    final accent =
        _blocked ? AppColors.destructive : AppColors.warning;
    final maxPlayers = structure.maxPlayersSupported;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _blocked
                    ? Icons.report_gmailerrorred_outlined
                    : Icons.schedule_outlined,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  _blocked
                      ? 'Your chip case is too small for this field'
                      : 'This structure runs past your finish time',
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _blocked ? _blockedNote(maxPlayers) : _overrunNote(),
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (onEditChips != null)
                AppButton(
                  variant: AppButtonVariant.secondary,
                  onPressed: onEditChips,
                  child: const Text('Edit chips'),
                ),
              if (onFewerRebuys != null)
                AppButton(
                  variant: AppButtonVariant.secondary,
                  onPressed: onFewerRebuys,
                  child: const Text('Fewer rebuys'),
                ),
              if (onPlayFreezeOut != null)
                AppButton(
                  variant: AppButtonVariant.secondary,
                  onPressed: onPlayFreezeOut,
                  child: const Text('Play a freeze-out'),
                ),
              if (onReduceField != null && maxPlayers != null)
                AppButton(
                  variant: AppButtonVariant.secondary,
                  onPressed: onReduceField,
                  child: Text('Reduce to $maxPlayers players'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// §F1.5 point 7's sentence, with the engine's own note preferred when it
  /// produced one.
  String _blockedNote(int? maxPlayers) {
    final engineNote = structure.depthShortfallNote;
    if (engineNote != null && engineNote.isNotEmpty) return engineNote;
    final covers = maxPlayers != null
        ? ' It covers up to $maxPlayers players with rebuys and add-ons.'
        : '';
    return 'Your chip case cannot give $players players a playable stack '
        '(at least ${TournamentEngineDepth.minPlayableBB} big blinds) with '
        'the forecast rebuys and add-ons.$covers Add chips, expect fewer '
        'rebuys or add-ons, or play a freeze-out.';
  }

  String _overrunNote() {
    final over = structure.paceOverByMins;
    final pace = structure.pace?.label ?? 'this pace';
    return over > 0
        ? 'At $pace the levels run about ${_hhmm(over)} past the time you '
            'set. Pick a later finish, a faster pace, or fewer chips in play.'
        : 'At $pace the levels run past the time you set.';
  }

  static String _hhmm(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m min';
    return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';
  }
}

/// The one engine constant this card quotes, kept here so the widget does not
/// pull the whole engine in for a single number.
abstract final class TournamentEngineDepth {
  /// §F1.2 `MIN_PLAYABLE_DEPTH`.
  static const int minPlayableBB = 20;
}
