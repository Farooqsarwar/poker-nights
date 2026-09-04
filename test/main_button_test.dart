// Main-button decision-matrix tests — user-flow spec §7.2 and §9.1 priority
// rules. Pure Dart against mainActionFor: no Firebase, no provider plumbing.
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/utils/main_button.dart';

TournamentStructure _structure() => const TournamentStructure(
      startingStack: 5000,
      chipPlan: [],
      rebuyStack: 3000,
      rebuyChipPlan: [],
      addOnStack: 0,
      addOnChipPlan: [],
      levels: [
        BlindLevel(level: 1, sb: 25, bb: 50, ante: null, durationMins: 15),
      ],
      levelDuration: 15,
      expectedFinishMins: 210,
      prizes: [],
      prizePool: 150,
      organizerAmount: 15,
      colorUpInstructions: [],
      warnings: [],
    );

GameSettings _settings() => GameSettings(
      name: 'Friday Night',
      date: '2026-08-28',
      time: '19:00',
      location: "Mike's basement",
      players: 6,
      durationHours: 3.5,
      buyIn: 15,
      koEnabled: false,
      koAmount: 0,
      rebuys: true,
      rebuysCloseLevel: 6,
      reEntry: false,
      addOn: true,
      anteEnabled: false,
      anteAfterLevel: 6,
      organizerPct: 10,
      chipSet: [
        ChipColor(color: 'white', hex: 0xFFFFFFFF, value: 25, quantity: 100),
      ],
      chipSetName: 'Home Set',
    );

LiveGame _game(LiveGameStatus status, {bool structureConfirmed = false}) =>
    LiveGame(
      id: 'game-1',
      groupId: 'grp-1',
      settings: _settings(),
      structure: _structure(),
      status: status,
      publicCode: 'ABC123',
      tvCode: 'TV789',
      currentLevel: 1,
      timerRunning: false,
      secondsRemaining: 900,
      players: const [],
      chat: [],
      announcements: [],
      totalChipsInPlay: 0,
      pendingGuests: [],
      finishOrder: [],
      structureConfirmed: structureConfirmed,
    );

Player _player({Rsvp? rsvp, bool checkedIn = false, bool confirmed = false}) =>
    Player(
      id: 'm1',
      name: 'Member',
      isGuest: false,
      rsvp: rsvp,
      checkedIn: checkedIn,
      confirmed: confirmed,
      eliminated: false,
      rebuys: 0,
      hasAddOn: false,
      knockouts: 0,
      table: 0,
      seat: 0,
      active: true,
    );

void _expectAction(
  MainAction action,
  MainActionId id,
  String label, {
  bool enabled = true,
  String? reason,
}) {
  expect(action.id, id, reason: reason);
  expect(action.label, label, reason: reason);
  expect(action.enabled, enabled,
      reason: '$id must be ${enabled ? '' : 'un'}tappable${reason == null ? '' : ' ($reason)'}');
}

void main() {
  group('admin rows', () {
    test('draft -> Edit Event', () {
      final a = mainActionFor(MainButtonRole.admin, _game(LiveGameStatus.draft));
      _expectAction(a, MainActionId.editEvent, 'Edit Event');
    });

    test('published -> Review RSVPs', () {
      final a =
          mainActionFor(MainButtonRole.admin, _game(LiveGameStatus.published));
      _expectAction(a, MainActionId.reviewRsvps, 'Review RSVPs');
    });

    test('checkin -> Manage Check-in', () {
      final a =
          mainActionFor(MainButtonRole.admin, _game(LiveGameStatus.checkin));
      _expectAction(a, MainActionId.openCheckIn, 'Manage Check-in');
    });

    test('ready without confirmed structure -> Generate Final Structure', () {
      final a = mainActionFor(
        MainButtonRole.admin,
        _game(LiveGameStatus.ready),
      );
      _expectAction(a, MainActionId.generateFinalStructure,
          'Generate Final Structure');
    });

    test('ready with confirmed structure -> Start Tournament', () {
      final a = mainActionFor(
        MainButtonRole.admin,
        _game(LiveGameStatus.ready, structureConfirmed: true),
      );
      _expectAction(a, MainActionId.startTournament, 'Start Tournament');
    });

    test('running/paused/finaltable -> Manage Tournament', () {
      for (final status in [
        LiveGameStatus.running,
        LiveGameStatus.paused,
        LiveGameStatus.finaltable,
      ]) {
        final a = mainActionFor(MainButtonRole.admin, _game(status));
        _expectAction(a, MainActionId.manageTournament, 'Manage Tournament',
            reason: 'status=$status');
      }
    });

    test('rebuypause -> Complete Rebuy & Add-on Break', () {
      final a = mainActionFor(
          MainButtonRole.admin, _game(LiveGameStatus.rebuypause));
      _expectAction(
          a, MainActionId.completeRebuyBreak, 'Complete Rebuy & Add-on Break');
    });

    test('completed/cancelled -> View Results', () {
      for (final status in [
        LiveGameStatus.completed,
        LiveGameStatus.cancelled,
      ]) {
        final a = mainActionFor(MainButtonRole.admin, _game(status));
        _expectAction(a, MainActionId.viewResults, 'View Results',
            reason: 'status=$status');
      }
    });
  });

  group('member rows', () {
    test('cancelled -> blocked', () {
      final a = mainActionFor(
        MainButtonRole.member,
        _game(LiveGameStatus.cancelled),
        memberRow: _player(rsvp: Rsvp.going),
      );
      // Blocking state (§9.1): visible but not tappable.
      _expectAction(a, MainActionId.blocked, 'Event Cancelled',
          enabled: false);
    });

    test('completed -> View Results', () {
      final a = mainActionFor(
        MainButtonRole.member,
        _game(LiveGameStatus.completed),
        memberRow: _player(rsvp: Rsvp.going),
      );
      _expectAction(a, MainActionId.viewResults, 'View Results');
    });

    test('running -> Open Live Tournament regardless of roster state', () {
      for (final row in [
        _player(), // no RSVP yet
        _player(rsvp: Rsvp.going, checkedIn: true, confirmed: true),
      ]) {
        final a = mainActionFor(
          MainButtonRole.member,
          _game(LiveGameStatus.running),
          memberRow: row,
        );
        _expectAction(a, MainActionId.openLiveTournament,
            'Open Live Tournament');
      }
    });

    test('absent from the roster -> Respond to Invitation', () {
      final a = mainActionFor(
        MainButtonRole.member,
        _game(LiveGameStatus.published),
        memberRow: null,
      );
      _expectAction(a, MainActionId.respondToInvitation,
          'Respond to Invitation');
    });

    test('no RSVP yet -> Respond to Invitation', () {
      final a = mainActionFor(
        MainButtonRole.member,
        _game(LiveGameStatus.checkin),
        memberRow: _player(rsvp: null),
      );
      _expectAction(a, MainActionId.respondToInvitation,
          'Respond to Invitation');
    });

    test('checked in but unconfirmed -> Waiting for Confirmation', () {
      final a = mainActionFor(
        MainButtonRole.member,
        _game(LiveGameStatus.published),
        memberRow: _player(rsvp: Rsvp.going, checkedIn: true),
      );
      // Blocking state (§9.1): visible but not tappable.
      _expectAction(a, MainActionId.waitingForConfirmation,
          'Waiting for Confirmation', enabled: false);
    });

    test('checked in and confirmed pre-live -> View My Seat', () {
      final a = mainActionFor(
        MainButtonRole.member,
        _game(LiveGameStatus.ready),
        memberRow: _player(rsvp: Rsvp.going, checkedIn: true, confirmed: true),
      );
      _expectAction(a, MainActionId.viewMySeat, 'View My Seat');
    });

    test('check-in open + going and not checked in -> Check In', () {
      final a = mainActionFor(
        MainButtonRole.member,
        _game(LiveGameStatus.checkin),
        memberRow: _player(rsvp: Rsvp.going),
      );
      _expectAction(a, MainActionId.checkIn, 'Check In');
    });

    test('check-in open + maybe and not checked in -> Check In', () {
      final a = mainActionFor(
        MainButtonRole.member,
        _game(LiveGameStatus.checkin),
        memberRow: _player(rsvp: Rsvp.maybe),
      );
      _expectAction(a, MainActionId.checkIn, 'Check In');
    });

    test('check-in open + cannot come -> Update RSVP', () {
      final a = mainActionFor(
        MainButtonRole.member,
        _game(LiveGameStatus.checkin),
        memberRow: _player(rsvp: Rsvp.cant),
      );
      _expectAction(a, MainActionId.updateRsvp, 'Update RSVP');
    });

    test('published + going before check-in opens -> Update RSVP', () {
      final a = mainActionFor(
        MainButtonRole.member,
        _game(LiveGameStatus.published),
        memberRow: _player(rsvp: Rsvp.going),
      );
      _expectAction(a, MainActionId.updateRsvp, 'Update RSVP');
    });
  });

  group('guest rows', () {
    test('unclaimed -> Claim My Guest Place', () {
      final a = mainActionFor(
        MainButtonRole.guest,
        _game(LiveGameStatus.published),
      );
      _expectAction(a, MainActionId.claimMyGuestPlace, 'Claim My Guest Place');
    });

    test('requested while published -> View Invitation', () {
      final a = mainActionFor(
        MainButtonRole.guest,
        _game(LiveGameStatus.published),
        guestRequested: true,
      );
      _expectAction(a, MainActionId.viewInvitation, 'View Invitation');
    });

    test('requested while check-in open -> Waiting for Confirmation', () {
      final a = mainActionFor(
        MainButtonRole.guest,
        _game(LiveGameStatus.checkin),
        guestRequested: true,
      );
      // Blocking state (§9.1): visible but not tappable.
      _expectAction(a, MainActionId.waitingForConfirmation,
          'Waiting for Confirmation', enabled: false);
    });

    test('confirmed pre-live -> View My Seat', () {
      final a = mainActionFor(
        MainButtonRole.guest,
        _game(LiveGameStatus.ready),
        guestRequested: true,
        guestConfirmed: true,
      );
      _expectAction(a, MainActionId.viewMySeat, 'View My Seat');
    });

    test('confirmed while running -> Open Live Tournament', () {
      final a = mainActionFor(
        MainButtonRole.guest,
        _game(LiveGameStatus.running),
        guestRequested: true,
        guestConfirmed: true,
      );
      _expectAction(
          a, MainActionId.openLiveTournament, 'Open Live Tournament');
    });

    test('completed -> View Results', () {
      final a = mainActionFor(
        MainButtonRole.guest,
        _game(LiveGameStatus.completed),
      );
      _expectAction(a, MainActionId.viewResults, 'View Results');
    });

    test('cancelled -> blocked', () {
      final a = mainActionFor(
        MainButtonRole.guest,
        _game(LiveGameStatus.cancelled),
      );
      // Blocking state (§9.1): visible but not tappable.
      _expectAction(a, MainActionId.blocked, 'Event Cancelled',
          enabled: false);
    });
  });
}
