import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/game.dart';
import '../../models/live_game.dart';
import '../../models/tournament_format.dart';
import '../../providers/app_provider.dart';
import '../../utils/structure_builder_controller.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_page.dart';
import '../../widgets/journey_progress.dart';
import '../../widgets/save_chip_set_offer.dart';
import '../../widgets/structure_builder.dart';

/// "Create structure" for a group event (route `/structure-review`, unchanged).
///
/// The shared stack-first [StructureBuilder] (WP2) seeded from the event: the
/// host sees the starting stack before any level, edits levels in place, moves
/// the rebuy close, and confirms. Every choice is saved on the event's
/// settings as it is made, so it survives Recalculate, leaving the screen and
/// reopening.
class StructureReviewScreen extends StatefulWidget {
  const StructureReviewScreen({super.key});

  @override
  State<StructureReviewScreen> createState() => _StructureReviewScreenState();
}

class _StructureReviewScreenState extends State<StructureReviewScreen> {
  StructureBuilderController? _controller;
  String? _controllerGameId;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  StructureBuilderController _controllerFor(AppProvider app, LiveGame game) {
    if (_controller != null && _controllerGameId == game.id) return _controller!;
    _controller?.dispose();
    final invited = game.players
        .where((player) => !player.isGuest && !player.noShow)
        .length;
    final firstBuild = game.structure.levels.isEmpty;
    final planned = firstBuild
        ? (invited >= 2 ? invited : game.settings.players)
        : app.plannedHeadcount(game);
    _controllerGameId = game.id;
    return _controller = StructureBuilderController.fromSettings(
      game.settings,
      players: planned >= 2 ? planned : game.settings.players,
      suggestRebuyLimit: firstBuild,
    );
  }

  /// Saves the builder's current state to the event without confirming it.
  void _persist(AppProvider app, StructureBuilderController c) {
    final game = app.currentGame;
    if (game == null) return;
    app.applyBuilderResult(c.applyTo(game.settings), c.resolved());
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final game = app.currentGame;

    if (!app.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(RoutePaths.invitation);
      });
      return const SizedBox.shrink();
    }

    if (game == null) {
      return AppEmptyState(
        title: 'No structure generated',
        description: 'Create a tournament to generate its structure.',
        action: AppButton(
          onPressed: () => context.go(RoutePaths.createTournament),
          child: const Text('Go back'),
        ),
      );
    }

    // Back honours the `?from=` query param so a host arriving from check-in
    // returns there; a bare link falls back to the invitation default.
    final backTo =
        RoutePaths.structureReviewFrom(GoRouterState.of(context).uri) ??
            RoutePaths.invitation;

    final header = <Widget>[
      JourneyProgress(
        game: game,
        currentRoute: RoutePaths.structureReview,
        onStepTap: (route) => context.go(route),
      ),
      const SizedBox(height: AppSpacing.lg),
      Row(
        children: [
          AppBackButton(onPressed: () => context.go(backTo)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create structure',
                  style: AppTypography.display(
                    size: AppFontSizes.xxxl,
                    weight: FontWeight.w700,
                  ),
                ),
                Text(
                  game.settings.name,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
    ];

    // Once play has started the stacks are physical; shootouts are generated
    // per table from the event settings. Neither can be rebuilt here.
    final frozen = game.stacksLocked;
    final shootout = game.settings.effectiveFormat == TournamentFormat.shootout;
    if (frozen || shootout) {
      return AppPage(
        maxWidth: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...header,
            AppCard(
              child: Text(
                frozen
                    ? 'Starting stacks are frozen once play has started. '
                        'Blinds and level lengths stay editable from the '
                        'dashboard.'
                    : 'A shootout structure is generated per table from the '
                        'event settings.',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
            if (shootout && !frozen) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                fullWidth: true,
                onPressed: () {
                  app.confirmStructure();
                  context.go(RoutePaths.invitation);
                },
                child: const Text('Confirm structure'),
              ),
            ],
          ],
        ),
      );
    }

    final controller = _controllerFor(app, game);
    final invited = game.players
        .where((player) => !player.isGuest && !player.noShow)
        .length;
    final going = game.goingWithGuestsCount;
    final maybe = game.players
        .where((player) => !player.isGuest && player.rsvp == Rsvp.maybe)
        .length;
    return AppPage(
      maxWidth: 640,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...header,
          if (app.paceProposalPending) ...[
            _PaceProposalCard(app: app),
            const SizedBox(height: AppSpacing.lg),
          ],
          StructureBuilder(
            controller: controller,
            confirmLabel: 'Save structure',
            playersHint: '$invited invited · $going Going · $maybe Maybe',
            onChipCountFixed: (counts) => offerSaveChipSet(
              context,
              app,
              counts,
              setName: game.settings.chipSetName,
            ),
            onEditChips: () => context.push(RoutePaths.chipSets),
            onPersist: () => _persist(app, controller),
            onConfirm: (s) {
              final saved = app.applyBuilderResult(
                controller.applyTo(game.settings),
                s,
                confirm: true,
              );
              if (saved && context.mounted) context.go(RoutePaths.invitation);
            },
          ),
        ],
      ),
    );
  }
}

/// §10.1: the group's own pace, offered — never applied — before generating.
class _PaceProposalCard extends StatelessWidget {
  const _PaceProposalCard({required this.app});

  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    final proposal = app.paceProposal;
    if (proposal == null) return const SizedBox.shrink();
    final pctLabel = (proposal.adjustmentPct.abs() * 100).toStringAsFixed(1);
    final runsLong = proposal.adjustmentPct > 0;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                "This group's own pace",
                style: AppTypography.bodySm.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Over the last ${proposal.sampleSize} nights this group averaged '
            '${proposal.meanActualMins.round()} min — '
            '${proposal.meanOverageMins.abs().round()} min '
            '${runsLong ? 'over' : 'under'} the ${proposal.targetDurationMins} '
            'min target. Accepting will ${runsLong ? 'shorten' : 'lengthen'} '
            'levels by $pctLabel% before generating.',
            style: AppTypography.bodySm.copyWith(
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
                onPressed: () => app.acceptPaceAdjustment(),
                child: Text(
                  'Accept ($pctLabel% ${runsLong ? 'shorter' : 'longer'})',
                ),
              ),
              AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.secondary,
                onPressed: () => app.declinePaceAdjustment(),
                child: const Text('Keep as planned'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
