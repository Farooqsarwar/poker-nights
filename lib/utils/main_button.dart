import '../app/route_paths.dart';
import '../models/game.dart';
import '../models/live_game.dart';

/// The single dominant next action for an event page (user-flow spec §7.2
/// and §9: "One event, one dominant next action").
///
/// The action is calculated from role, event state, RSVP state and check-in
/// state only — never from screen position — so every surface (home cards,
/// event page, chat pinned card) can render the same answer to "What should
/// I do next?".
enum MainButtonRole { admin, member, guest }

/// Every primary action the product can present, one row of the spec §7.2
/// matrix plus the blocking states from the §9.1 priority rules.
enum MainActionId {
  // Admin rows
  editEvent,
  reviewRsvps,
  openCheckIn,
  generateFinalStructure,
  startTournament,
  manageTournament,
  completeRebuyBreak,
  // Member rows
  respondToInvitation,
  updateRsvp,
  checkIn,
  viewMySeat,
  openLiveTournament,
  // Guest rows
  claimMyGuestPlace,
  viewInvitation,
  // Shared rows / blocking states
  waitingForConfirmation,
  viewResults,
  blocked,
}

/// A resolved main-button action: its id, human label, destination route and
/// whether it is interactive. Blocking states ([MainActionId.blocked],
/// [MainActionId.waitingForConfirmation]) keep their label visible but are
/// not tappable — the app must never offer an unavailable action (§9).
class MainAction {
  const MainAction(this.id, this.label, {this.route, this.enabled = true});

  final MainActionId id;
  final String label;

  /// Default navigation target for this action (may be ignored by callers
  /// that route differently, e.g. deep-linking into a specific game).
  final String? route;

  final bool enabled;
}

/// True while the tournament is in any live operational mode (§3 lifecycle:
/// Live, Rebuy+Add-on Break and Final Table are all "during play" states).
bool _isLive(LiveGameStatus s) =>
    s == LiveGameStatus.running ||
    s == LiveGameStatus.paused ||
    s == LiveGameStatus.rebuypause ||
    s == LiveGameStatus.finaltable;

/// True once door check-in has opened (status moved past RSVP-only phases).
bool _checkInOpen(LiveGame game) {
  switch (game.status) {
    case LiveGameStatus.checkin:
    case LiveGameStatus.ready:
    case LiveGameStatus.running:
    case LiveGameStatus.paused:
    case LiveGameStatus.rebuypause:
    case LiveGameStatus.finaltable:
      return true;
    case LiveGameStatus.draft:
    case LiveGameStatus.published:
    case LiveGameStatus.completed:
    case LiveGameStatus.cancelled:
      return false;
  }
}

/// Resolves the dominant next action for [role] on [game].
///
/// * [memberRow] — the registered member's own roster row (`null` when the
///   viewer is absent from the player list or is not a member).
/// * [guestRequested] — a guest device has claimed a slot / requested
///   check-in but the admin has not confirmed yet.
/// * [guestConfirmed] — the admin has confirmed the guest (seat assigned).
MainAction mainActionFor(
  MainButtonRole role,
  LiveGame game, {
  Player? memberRow,
  bool guestRequested = false,
  bool guestConfirmed = false,
}) {
  switch (role) {
    case MainButtonRole.admin:
      return _adminAction(game);
    case MainButtonRole.member:
      return _memberAction(game, memberRow);
    case MainButtonRole.guest:
      return _guestAction(game, requested: guestRequested, confirmed: guestConfirmed);
  }
}

/// Admin matrix (§7.2): Draft → Review RSVPs; Published → Review RSVPs;
/// Check-in available → Open Check-in; Attendance confirmed → Generate Final
/// Structure; Ready → Start Tournament; Live → Manage Tournament; Rebuy
/// break → Complete Rebuy & Add-on Break; Finished → View Results.
///
/// In this implementation the structure review doubles as the "Generate Final
/// Structure" step: [LiveGame.structureConfirmed] distinguishes generating
/// from starting once attendance is confirmed (status `ready`).
MainAction _adminAction(LiveGame game) {
  switch (game.status) {
    case LiveGameStatus.draft:
      // Spec §7.2: Draft → "Edit Event". The event page allows editing
      // draft settings before anything is shared with members.
      return const MainAction(
        MainActionId.editEvent,
        'Edit Event',
        route: RoutePaths.invitation,
      );
    case LiveGameStatus.published:
      return const MainAction(
        MainActionId.reviewRsvps,
        'Review RSVPs',
        route: RoutePaths.invitation,
      );
    case LiveGameStatus.checkin:
      return const MainAction(
        MainActionId.openCheckIn,
        'Open Check-in',
        route: RoutePaths.checkIn,
      );
    case LiveGameStatus.ready:
      return game.structureConfirmed
          ? const MainAction(
              MainActionId.startTournament,
              'Start Tournament',
              route: RoutePaths.structureReview,
            )
          : const MainAction(
              MainActionId.generateFinalStructure,
              'Generate Final Structure',
              route: RoutePaths.structureReview,
            );
    case LiveGameStatus.running:
    case LiveGameStatus.paused:
    case LiveGameStatus.finaltable:
      return const MainAction(
        MainActionId.manageTournament,
        'Manage Tournament',
        route: RoutePaths.adminDashboard,
      );
    case LiveGameStatus.rebuypause:
      return const MainAction(
        MainActionId.completeRebuyBreak,
        'Complete Rebuy & Add-on Break',
        route: RoutePaths.rebuySettlement,
      );
    case LiveGameStatus.completed:
    case LiveGameStatus.cancelled:
      return const MainAction(
        MainActionId.viewResults,
        'View Results',
        route: RoutePaths.resultPodium,
      );
  }
}

/// Registered-member priority chain (§9.1): blocking states first, then
/// finish > awaiting-approval > respond > check-in > seat > live.
///
/// During play every member — including no-shows and the eliminated — keeps
/// "Open Live Tournament": eliminated members remain part of the experience
/// (§5.7) and must still see timer, players remaining and Prize Pool.
MainAction _memberAction(LiveGame game, Player? me) {
  if (game.status == LiveGameStatus.cancelled) {
    return const MainAction(
      MainActionId.blocked,
      'Event Cancelled',
      enabled: false,
    );
  }
  if (game.status == LiveGameStatus.completed) {
    return const MainAction(
      MainActionId.viewResults,
      'View Results',
      route: RoutePaths.resultPodium,
    );
  }
  if (_isLive(game.status)) {
    return const MainAction(
      MainActionId.openLiveTournament,
      'Open Live Tournament',
      route: RoutePaths.playerLive,
    );
  }
  if (me == null || me.rsvp == null) {
    return const MainAction(
      MainActionId.respondToInvitation,
      'Respond to Invitation',
      route: RoutePaths.invitation,
    );
  }
  // Requested check-in, admin has not confirmed yet — blocking state (§9.1).
  if (me.checkedIn && !me.confirmed) {
    return const MainAction(
      MainActionId.waitingForConfirmation,
      'Waiting for Confirmation',
      enabled: false,
    );
  }
  if (me.checkedIn && me.confirmed) {
    return const MainAction(
      MainActionId.viewMySeat,
      'View My Seat',
      route: RoutePaths.playerLive,
    );
  }
  if (_checkInOpen(game) && me.rsvp != Rsvp.cant) {
    return const MainAction(
      MainActionId.checkIn,
      'Check In',
      // Members self-check-in from the invitation screen (the admin-only
      // check-in page redirects them away). Routing here avoids the dead-end.
      route: RoutePaths.invitation,
    );
  }
  return const MainAction(
    MainActionId.updateRsvp,
    'Update RSVP',
    route: RoutePaths.invitation,
  );
}

/// Guest chain (§6 + §7.2 guest rows): Unclaimed → Claim My Guest Place;
/// Slot reserved (before check-in opens) → View Invitation; Check-in open →
/// Check In; Check-in pending → Waiting for Confirmation; Checked in →
/// View My Seat; Live → Open Live Tournament; Finished → View Results.
MainAction _guestAction(
  LiveGame game, {
  required bool requested,
  required bool confirmed,
}) {
  if (game.status == LiveGameStatus.cancelled) {
    return const MainAction(
      MainActionId.blocked,
      'Event Cancelled',
      enabled: false,
    );
  }
  if (game.status == LiveGameStatus.completed) {
    return const MainAction(
      MainActionId.viewResults,
      'View Results',
      route: RoutePaths.resultPodium,
    );
  }
  if (_isLive(game.status)) {
    return const MainAction(
      MainActionId.openLiveTournament,
      'Open Live Tournament',
      route: RoutePaths.playerLive,
    );
  }
  if (confirmed) {
    return const MainAction(
      MainActionId.viewMySeat,
      'View My Seat',
      route: RoutePaths.playerLive,
    );
  }
  if (requested && _checkInOpen(game)) {
    return const MainAction(
      MainActionId.waitingForConfirmation,
      'Waiting for Confirmation',
      enabled: false,
    );
  }
  if (requested) {
    return const MainAction(
      MainActionId.viewInvitation,
      'View Invitation',
      route: RoutePaths.guestFlow,
    );
  }
  return const MainAction(
    MainActionId.claimMyGuestPlace,
    'Claim My Guest Place',
    route: RoutePaths.guestFlow,
  );
}
