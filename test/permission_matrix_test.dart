import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/services/permissions.dart';

/// Specification §28's permission matrix, transcribed cell by cell.
///
/// The matrix is the contract for the Tournament Organizer role, and the role
/// is the one §32 lists as a decision that must not drift. Asserting it as a
/// table means a change to the rules shows up as a failing cell rather than as
/// a subtle difference nobody notices until an organizer deletes a group.
void main() {
  // §28, exactly as written. Rows are actions, columns Member / Organizer /
  // Admin. The organizer column is evaluated for their ASSIGNED game.
  const matrix = <Capability, ({bool member, bool organizer, bool admin})>{
    Capability.viewGroup: (member: true, organizer: true, admin: true),
    Capability.chatAndPolls: (member: true, organizer: true, admin: true),
    Capability.createEvent: (member: true, organizer: true, admin: true),
    Capability.rsvpOwnGuests: (member: true, organizer: true, admin: true),
    Capability.approveMembership: (member: false, organizer: false, admin: true),
    Capability.editGroupSettings: (member: false, organizer: false, admin: true),
    Capability.manageAdmins: (member: false, organizer: false, admin: true),
    Capability.runThisTournament: (member: false, organizer: true, admin: true),
    Capability.runOtherTournaments:
        (member: false, organizer: false, admin: true),
    Capability.rebuyAddOnOps: (member: false, organizer: true, admin: true),
    Capability.seatingRebalance: (member: false, organizer: true, admin: true),
    Capability.viewPrivateFinancials:
        (member: false, organizer: true, admin: true),
    Capability.deleteGroup: (member: false, organizer: false, admin: true),
  };

  group('§28 — every cell of the permission matrix', () {
    matrix.forEach((capability, expected) {
      final name = capability.name;

      test('$name — member', () {
        expect(Permissions.can(capability, Actor.member), expected.member);
      });

      test('$name — organizer, assigned game', () {
        expect(
          Permissions.can(capability, Actor.organizer),
          expected.organizer,
        );
      });

      test('$name — admin', () {
        expect(Permissions.can(capability, Actor.admin), expected.admin);
      });
    });

    test('the matrix covers every capability', () {
      // A capability added without a row here would silently go untested.
      expect(matrix.keys.toSet(), Capability.values.toSet());
    });
  });

  group('the organizer role is tournament-scoped (§3, §32)', () {
    test('operational rights evaporate outside the assigned game', () {
      for (final c in [
        Capability.runThisTournament,
        Capability.rebuyAddOnOps,
        Capability.seatingRebalance,
        Capability.viewPrivateFinancials,
      ]) {
        expect(
          Permissions.can(c, Actor.organizer, isAssignedGame: false),
          isFalse,
          reason: '${c.name}: §3 — an organizer may not "access other '
              "tournaments' private data\"",
        );
      }
    });

    test('an admin keeps everything in every game', () {
      for (final c in Capability.values) {
        expect(
          Permissions.can(c, Actor.admin, isAssignedGame: false),
          isTrue,
          reason: c.name,
        );
      }
    });

    test('an organizer never gains a group-level right', () {
      for (final c in [
        Capability.approveMembership,
        Capability.editGroupSettings,
        Capability.manageAdmins,
        Capability.deleteGroup,
        Capability.runOtherTournaments,
      ]) {
        expect(Permissions.can(c, Actor.organizer), isFalse, reason: c.name);
      }
    });
  });

  group('guests are event-scoped (§32)', () {
    test('a guest can do nothing in the group', () {
      for (final c in Capability.values) {
        expect(Permissions.can(c, Actor.guest), isFalse, reason: c.name);
      }
    });
  });

  group('every actor has a label for the UI', () {
    test('labels are present', () {
      for (final a in Actor.values) {
        expect(a.label, isNotEmpty);
      }
    });
  });
}
