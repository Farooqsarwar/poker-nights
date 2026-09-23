import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/route_paths.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../models/live_game.dart';
import 'status_dot.dart';

/// One stage of the pre-live tournament journey.
///
/// Order is fixed: details, structure, invites, check-in, seating, start.
/// Each value carries the [route] of the screen that owns it, so the screen
/// that mounts [JourneyProgress] can navigate without this widget depending
/// on a router directly.
enum JourneyStep {
  details(route: RoutePaths.invitation),
  structure(route: RoutePaths.structureReview),
  invites(route: RoutePaths.invitation),
  checkin(route: RoutePaths.checkIn),
  seating(route: RoutePaths.checkIn),
  start(route: RoutePaths.adminDashboard);

  const JourneyStep({required this.route});

  /// The screen that owns this step. The mounting screen decides how to
  /// navigate (the app convention is `context.go(step.route)`).
  final String route;

  /// Short label shown under the dot.
  String get label => switch (this) {
        JourneyStep.details => 'Details',
        JourneyStep.structure => 'Structure',
        JourneyStep.invites => 'Invites',
        JourneyStep.checkin => 'Check-in',
        JourneyStep.seating => 'Seating',
        JourneyStep.start => 'Start',
      };
}

/// Persistent journey header shown at the top of the three pre-live screens
/// (invitation, structure review, check-in).
///
/// Renders as a single compact row of small labelled dots (see the Task C
/// spec): done steps show a green check, the current step a filled dot, and
/// upcoming steps a hollow dot — `Details ✓ → Structure ✓ → Invites ✓ →
/// Check-in ● → Seating ○ → Start ○`.
///
/// Every step's done-ness is derived purely from the [LiveGame] it is handed;
/// nothing is added to the model and nothing is stored. Done-ness:
///
/// * Details — always (the game exists).
/// * Structure — `game.structureConfirmed`.
/// * Invites — `game.status.index >= LiveGameStatus.published.index`.
/// * Check-in — any player `checkedIn`.
/// * Seating — `game.seatingConfirmed`.
/// * Start — `game.status.isActiveLive`.
///
/// All state is derived, so the widget is stateless and purely presentational.
/// Tapping a step fires [onStepTap] with that step; navigation itself is left
/// to the mounting screen, which typically wires
/// `onStepTap: (step) => context.go(step.route)`.
class JourneyProgress extends StatelessWidget {
  const JourneyProgress({
    super.key,
    required this.game,
    this.onStepTap,
    this.padding,
    this.currentRoute,
  });

  /// The game whose state drives every step.
  final LiveGame game;

  /// The route this strip is mounted on, so steps pointing back at the
  /// current screen render as plain labels instead of dead buttons.
  ///
  /// Passed in rather than read from the router: several steps share a route
  /// (details and invites are both the invitation screen), so on any given
  /// screen at least one dot is self-referential, and a third of the strip
  /// doing nothing teaches people it is not worth tapping. Supplied by the
  /// caller to keep this widget free of a router dependency — the same
  /// reason [JourneyStep.route] is data rather than a navigation call.
  final String? currentRoute;

  /// Fired with the tapped step so the mounting screen can dispatch the
  /// navigation. When null the steps render but ignore taps.
  final ValueChanged<JourneyStep>? onStepTap;

  /// Horizontal outer padding; defaulted to match a typical content column.
  /// Override so the strip lines up with the mounting screen's own insets.
  final EdgeInsetsGeometry? padding;

  /// Whether [step] is complete for [game].
  static bool isDone(JourneyStep step, LiveGame game) => switch (step) {
        JourneyStep.details => true,
        JourneyStep.structure => game.structureConfirmed,
        JourneyStep.invites =>
          game.status.index >= LiveGameStatus.published.index,
        JourneyStep.checkin => game.players.any((p) => p.checkedIn),
        JourneyStep.seating => game.seatingConfirmed,
        JourneyStep.start => game.status.isActiveLive,
      };

  /// The first not-done step, or null once every step is complete.
  static JourneyStep? currentStep(LiveGame game) {
    for (final step in JourneyStep.values) {
      if (!isDone(step, game)) return step;
    }
    return null;
  }

  /// The route [step] maps to — convenience that mirrors `step.route` so the
  /// mounting screen can do `context.go(journey.routeFor(step))`.
  String routeFor(JourneyStep step) => step.route;

  @override
  Widget build(BuildContext context) {
    final current = currentStep(game);
    final here = currentRoute;
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: 0.6),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < JourneyStep.values.length; i++) ...[
            if (i > 0) const _JourneyConnector(),
            Expanded(
              child: _JourneyStepItem(
                step: JourneyStep.values[i],
                done: isDone(JourneyStep.values[i], game),
                current: JourneyStep.values[i] == current,
                // A step whose route is the screen we are already on is not
                // a destination. Leaving it tappable makes a third of the
                // dots do nothing on any given screen, which teaches people
                // the strip is unreliable and stops them using it at all.
                onTap: onStepTap == null || JourneyStep.values[i].route == here
                    ? null
                    : () => onStepTap!(JourneyStep.values[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

const double _kDotSize = 10;
const double _kStepVerticalPadding = AppSpacing.xs;

/// Thin connector line drawn between dots. Its height is the whole step row
/// so the line stays vertically centered on the dots regardless of the label
/// (both the dot and the connector keep identical top padding).
class _JourneyConnector extends StatelessWidget {
  const _JourneyConnector();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: _kDotSize + 2 * _kStepVerticalPadding,
      child: Center(
        child: Container(
          width: 14,
          height: 2,
          decoration: BoxDecoration(
            color: AppColors.border.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}

/// One labelled journey step. The dot visually encodes three states, matching
/// the app's dot vocabulary (see [StatusDot]):
///
/// * done — green fill (reused from [StatusDot]) with a check glyph;
/// * current — filled ringed dot in primary;
/// * upcoming — hollow circle in the muted foreground.
class _JourneyStepItem extends StatelessWidget {
  const _JourneyStepItem({
    required this.step,
    required this.done,
    required this.current,
    required this.onTap,
  });

  final JourneyStep step;
  final bool done;
  final bool current;
  final VoidCallback? onTap;

  Widget _dot(BuildContext context) {
    if (done) {
      return SizedBox(
        width: _kDotSize,
        height: _kDotSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            StatusDot(status: AppStatus.online, size: _kDotSize),
            Icon(Icons.check, size: 8, color: AppColors.successForeground),
          ],
        ),
      );
    }
    if (current) {
      return Container(
        width: _kDotSize,
        height: _kDotSize,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.ring),
        ),
      );
    }
    return Container(
      width: _kDotSize,
      height: _kDotSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.mutedForeground, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (labelColor, weight) = switch ((done, current)) {
      (true, _) => (AppColors.successText, FontWeight.w600),
      (false, true) => (AppColors.primaryText, FontWeight.w600),
      _ => (AppColors.mutedForeground, FontWeight.w500),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Semantics(
        label:
            '${step.label}: ${done ? 'done' : current ? 'current step' : 'upcoming'}',
        button: onTap != null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: _kStepVerticalPadding,
            horizontal: AppSpacing.xxs,
          ),
          child: Column(
            children: [
              _dot(context),
              const SizedBox(height: AppSpacing.xxs),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  step.label,
                  maxLines: 1,
                  style: AppTypography.bodyXs.copyWith(
                    color: labelColor,
                    fontWeight: weight,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Standalone harness for smoke-testing [JourneyProgress] in widget tests
/// without mounting an app screen.
///
/// Never used by the app itself: it exists so later agents or tests can pump a
/// self-contained, router-free version of the strip. Because it embeds its own
/// [Material] and [Directionality], it works when pumped directly with
/// `tester.pumpWidget(JourneyProgressPreview(game: someGame))`.
class JourneyProgressPreview extends StatelessWidget {
  const JourneyProgressPreview({
    super.key,
    required this.game,
    this.onStepTap,
  });

  /// The game to render the journey for.
  final LiveGame game;

  /// Forwarded straight to [JourneyProgress.onStepTap].
  final ValueChanged<JourneyStep>? onStepTap;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: AppColors.background,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: JourneyProgress(
            game: game,
            onStepTap: onStepTap,
          ),
        ),
      ),
    );
  }
}