import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/utils/model_codec.dart';

/// The check-in race.
///
/// The sequence that lost check-ins:
///   1. host taps Open check-in, which triggers a whole-document save
///   2. the save reads the document — the member has not checked in yet
///   3. THE MEMBER TAPS CHECK IN, right in the window, because opening
///      check-in is exactly what prompts them
///   4. the host's `.set()` lands and reverts `checkedIn` to false
///   5. the member's optimistic overlay still shows them checked in, so
///      nobody notices; the host's queue stays empty
///   6. some later change makes `_maybeReassertOwnCheckIn` re-send the patch,
///      which is why it "works the second time"
///
/// The merge now runs INSIDE the write transaction, against the copy read in
/// that same transaction, so step 3 can no longer be overwritten. These tests
/// pin the merge contract that fix depends on.

const _structure = TournamentStructure(
  startingStack: 5000,
  chipPlan: [],
  rebuyStack: 5000,
  rebuyChipPlan: [],
  addOnStack: 5000,
  addOnChipPlan: [],
  levels: [BlindLevel(level: 1, sb: 25, bb: 50, ante: null, durationMins: 15)],
  levelDuration: 15,
  expectedFinishMins: 225,
  prizes: [],
  prizePool: 0,
  organizerAmount: 0,
  colorUpInstructions: [],
  warnings: [],
);

const _settings = GameSettings(
  name: 'Friday',
  date: '2026-09-08',
  time: '20:00',
  location: 'Basement',
  players: 8,
  durationHours: 3.5,
  buyIn: 15,
  koEnabled: false,
  koAmount: 0,
  rebuys: true,
  rebuysCloseLevel: 6,
  addOn: true,
  anteEnabled: false,
  anteAfterLevel: 7,
  organizerPct: 0,
  chipSet: [],
  chipSetName: 'Home',
);

Player _member(String id, {Rsvp? rsvp, bool checkedIn = false}) => Player(
  id: id,
  name: id.toUpperCase(),
  isGuest: false,
  rsvp: rsvp,
  checkedIn: checkedIn,
  confirmed: false,
  eliminated: false,
  rebuys: 0,
  hasAddOn: false,
  knockouts: 0,
  table: 0,
  seat: 0,
  active: true,
);

LiveGame _game(List<Player> players) => LiveGame(
  id: 'game-1',
  groupId: 'grp-1',
  settings: _settings,
  structure: _structure,
  status: LiveGameStatus.checkin,
  publicCode: 'ABC123',
  tvCode: 'TV7890',
  currentLevel: 1,
  timerRunning: false,
  secondsRemaining: 900,
  players: players,
  chat: const [],
  announcements: const [],
  totalChipsInPlay: 0,
  pendingGuests: const [],
  finishOrder: const [],
);

void main() {
  group('a check-in landing mid-save survives the write', () {
    test('the member ends up checked in, not reverted', () {
      // What the host was about to write: u2 not checked in.
      final aboutToWrite = _game([
        _member('admin'),
        _member('u2', rsvp: Rsvp.going),
      ]);
      // What is on the server by the time the transaction reads it.
      final serverNow = _game([
        _member('admin'),
        _member('u2', rsvp: Rsvp.going, checkedIn: true),
      ]);

      final committed = mergeMemberOwnedFields(
        aboutToWrite,
        serverNow,
        adminId: 'admin',
      );

      expect(
        committed.players.firstWhere((p) => p.id == 'u2').checkedIn,
        isTrue,
        reason: 'the host save overwrote a check-in that had already landed',
      );
      expect(
        committed.players.firstWhere((p) => p.id == 'u2').confirmed,
        isFalse,
        reason: 'confirming stays an admin action',
      );
    });

    test('the host keeps their own concurrent edit', () {
      final aboutToWrite = _game([
        _member('admin', rsvp: Rsvp.going),
        _member('u2', rsvp: Rsvp.going),
      ]);
      final serverNow = _game([
        _member('admin', rsvp: Rsvp.cant),
        _member('u2', rsvp: Rsvp.going, checkedIn: true),
      ]);

      final committed = mergeMemberOwnedFields(
        aboutToWrite,
        serverNow,
        adminId: 'admin',
      );

      expect(
        committed.players.firstWhere((p) => p.id == 'admin').rsvp,
        Rsvp.going,
        reason: 'only member-owned fields may cross over',
      );
      expect(
        committed.players.firstWhere((p) => p.id == 'u2').checkedIn,
        isTrue,
      );
    });

    test('a member who appeared mid-save is not dropped', () {
      final aboutToWrite = _game([_member('admin')]);
      final serverNow = _game([
        _member('admin'),
        _member('late', rsvp: Rsvp.going, checkedIn: true),
      ]);

      final committed = mergeMemberOwnedFields(
        aboutToWrite,
        serverNow,
        adminId: 'admin',
      );

      final late = committed.players.where((p) => p.id == 'late');
      expect(late, hasLength(1));
      expect(late.single.checkedIn, isTrue);
    });

    test('a stale server row never un-checks somebody', () {
      final aboutToWrite = _game([
        _member('admin'),
        _member('u2', rsvp: Rsvp.going, checkedIn: true),
      ]);
      final serverNow = _game([
        _member('admin'),
        _member('u2', rsvp: Rsvp.going),
      ]);

      final committed = mergeMemberOwnedFields(
        aboutToWrite,
        serverNow,
        adminId: 'admin',
      );

      expect(
        committed.players.firstWhere((p) => p.id == 'u2').checkedIn,
        isTrue,
      );
    });
  });

  group('what was committed is what the host then shows', () {
    test('re-merging the committed copy is a fixpoint', () {
      // `_adoptCommittedMemberFields` re-merges the committed copy onto the
      // host's live game. If that were not a fixpoint, `_currentGame` would
      // sit permanently behind `_lastSavedSignature`, re-flagging the game
      // dirty on every notify and re-saving forever — and every snapshot that
      // loop produced would carry this device's own writerId and be skipped
      // by the echo guard.
      final live = _game([
        _member('admin'),
        _member('u2', rsvp: Rsvp.going),
      ]);
      final serverNow = _game([
        _member('admin'),
        _member('u2', rsvp: Rsvp.going, checkedIn: true),
      ]);

      final committed = mergeMemberOwnedFields(
        live,
        serverNow,
        adminId: 'admin',
      );
      final shown = mergeMemberOwnedFields(live, committed, adminId: 'admin');
      final again = mergeMemberOwnedFields(shown, committed, adminId: 'admin');

      expect(
        identical(again, shown),
        isTrue,
        reason: 'a second pass must change nothing',
      );
      expect(
        jsonEncode(liveGameToMap(shown)),
        jsonEncode(liveGameToMap(committed)),
        reason: 'the host must display exactly what was written',
      );
    });

    test('nothing to merge leaves the game untouched', () {
      final g = _game([
        _member('admin'),
        _member('u2', rsvp: Rsvp.going, checkedIn: true),
      ]);
      expect(
        identical(mergeMemberOwnedFields(g, g, adminId: 'admin'), g),
        isTrue,
      );
    });
  });
}
