import '../models/group.dart';
import '../models/live_game.dart';
import '../models/user.dart';

/// Everything a person might be allowed to do (§28's action column).
enum Capability {
  viewGroup,
  chatAndPolls,
  createEvent,
  rsvpOwnGuests,
  approveMembership,
  editGroupSettings,
  manageAdmins,
  runThisTournament,
  runOtherTournaments,
  rebuyAddOnOps,
  seatingRebalance,
  viewPrivateFinancials,
  deleteGroup,
}

/// Who somebody is, for the purposes of one tournament.
///
/// Deliberately resolved per-game rather than per-user: §32 fixes the
/// Tournament Organizer as tournament-scoped, so the same person is an
/// organizer at Friday's game and an ordinary member at Saturday's.
enum Actor {
  guest,
  member,
  organizer,
  admin;

  String get label => switch (this) {
        Actor.guest => 'Guest',
        Actor.member => 'Member',
        Actor.organizer => 'Tournament Organizer',
        Actor.admin => 'Admin',
      };
}

/// §28's permission matrix, transcribed.
///
/// One table, in one place, so it can be compared against the specification
/// line by line — rather than a dozen `isAdmin ||` checks scattered through
/// screens where nobody can tell whether they collectively match.
///
/// The one non-binary cell in §28 is `Private financials → Organizer →
/// "Assigned game"`, which is why [can] takes the game: the answer genuinely
/// depends on WHICH tournament is being asked about.
abstract final class Permissions {
  /// Resolves what [user] is, for [game].
  ///
  /// **Decision (D7): a guest can never be an organizer.** The specification
  /// does not say, so: §32 fixes guests as event-scoped and an organizer needs
  /// an account-level identity to be assigned, audited and held responsible
  /// across check-in, seating and money. A guest has none of that — they are a
  /// name in a slot. They join the group first, then they can run a night.
  static Actor actorFor({
    required AppUser? user,
    required Group group,
    LiveGame? game,
    bool isGuestSession = false,
  }) {
    if (isGuestSession || user == null) return Actor.guest;
    if (group.ownerId == user.id ||
        group.members.any((m) => m.id == user.id && m.isAdmin)) {
      return Actor.admin;
    }
    if (game != null && game.isOrganizer(user.id)) return Actor.organizer;
    if (group.members.any((m) => m.id == user.id)) return Actor.member;
    return Actor.guest;
  }

  /// Whether [actor] may do [capability].
  ///
  /// [isAssignedGame] distinguishes §28's "Assigned game" cell: an organizer's
  /// rights exist only inside the tournament they were given, and evaporate
  /// everywhere else.
  static bool can(
    Capability capability,
    Actor actor, {
    bool isAssignedGame = true,
  }) {
    switch (capability) {
      // Everyone who is in the group.
      case Capability.viewGroup:
      case Capability.chatAndPolls:
      case Capability.createEvent:
      case Capability.rsvpOwnGuests:
        return actor != Actor.guest;

      // Admin only — §3: "Organizer cannot remove members, delete group, edit
      // group settings, approve membership, manage admins".
      case Capability.approveMembership:
      case Capability.editGroupSettings:
      case Capability.manageAdmins:
      case Capability.deleteGroup:
      case Capability.runOtherTournaments:
        return actor == Actor.admin;

      // Operational control: admin anywhere, organizer in their own game.
      case Capability.runThisTournament:
      case Capability.rebuyAddOnOps:
      case Capability.seatingRebalance:
        return actor == Actor.admin ||
            (actor == Actor.organizer && isAssignedGame);

      // §28's one conditional cell: "Private financials → Organizer →
      // Assigned game".
      case Capability.viewPrivateFinancials:
        return actor == Actor.admin ||
            (actor == Actor.organizer && isAssignedGame);
    }
  }
}
