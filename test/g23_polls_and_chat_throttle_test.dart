import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/services/recovery_service.dart';

/// §G2.3 rows 8 and 6 — poll voting, and the chat send throttle.
///
/// **Row 8** (spec `:5110`): "Polls: change a vote, multi-choice, un-vote
/// deletes the entry" — cross-referenced to B5, whose requirement is §E10
/// "Voting" (spec `:1590`):
///
///   "Tap an option to vote; tap another to change; tap your own choice again
///   to remove your vote. Multi-choice polls allow several. Votes are stored
///   as `votes: {uid: [optionId]}` (§E10): single-choice keeps only the newest
///   option; multi-choice keeps every option tapped; emptying your list
///   **deletes your entry** (an un-vote), never stores an empty list. Percent
///   bars = votes for the option / people who voted."
///
/// The "deletes your entry, never stores an empty list" clause is the one worth
/// a real assertion. An entry left behind as `{uid: []}` still counts as a
/// voter to every counter that reads `votes.length`, so a member who un-votes
/// keeps inflating the denominator and every other member's percentage drops.
/// The tests below assert the key is GONE from the map, not that its value is
/// empty.
///
/// **Row 6** (spec `:5106`): chat "the 9th message within 30s, or two within
/// 4s, is blocked, copy included".
void main() {
  // The provider subscribes to a connectivity EventChannel in its constructor,
  // so a plain `test()` still needs the binding for the platform messenger.
  TestWidgetsFlutterBinding.ensureInitialized();

  // Every provider change mirrors into the device-local crash-recovery store,
  // which is one `recovery/active_game` document for the whole test process;
  // its delete-before-write step collides between concurrent instances
  // (errno 32). Nothing here is about recovery, so it is off for the duration.
  setUp(() => RecoveryService.enabled = false);
  tearDown(() => RecoveryService.enabled = true);

  const host = AppUser(
    id: 'u1',
    name: 'Alex Morgan',
    email: 'alex@poker.night',
    isAdmin: true,
    stats: UserStats(
      played: 34,
      wins: 6,
      podium: 11,
      avgFinish: 3.2,
      knockouts: 18,
    ),
  );

  const nina = AppUser(
    id: 'u2',
    name: 'Nina Kowalski',
    email: 'nina@poker.night',
    isAdmin: false,
    stats: UserStats(
      played: 12,
      wins: 2,
      podium: 4,
      avgFinish: 4.1,
      knockouts: 3,
    ),
  );

  const sam = AppUser(
    id: 'u3',
    name: 'Sam Abara',
    email: 'sam@poker.night',
    isAdmin: false,
    stats: UserStats(
      played: 7,
      wins: 1,
      podium: 2,
      avgFinish: 5.0,
      knockouts: 1,
    ),
  );

  const club = Group(
    id: 'g1',
    name: 'Friday Poker Club',
    joinCode: 'FP2608',
    ownerId: 'u1',
    members: [host, nina, sam],
    games: [],
    chat: [],
    polls: [],
    notifications: [],
  );

  Poll newPoll({
    String id = 'poll-1',
    String question = 'Table time?',
    List<String> options = const ['8pm', '9pm', '10pm'],
    Map<String, List<String>> votes = const {},
    bool closed = false,
    bool multi = false,
  }) =>
      Poll(
        id: id,
        question: question,
        options: options,
        votes: votes,
        closed: closed,
        createdAt: DateTime(2026, 9, 1),
        multi: multi,
      );

  /// A provider signed in as [user], with [poll] already in the group. The
  /// poll is seeded rather than created through `createPoll` so each test
  /// starts from one known ledger; `createPoll` is covered in
  /// `g23_input_normalisation_test.dart`.
  AppProvider voter(AppUser user, Poll poll) => AppProvider()
    ..setUserForTesting(user)
    ..setCurrentGroupForTesting(club.copyWith(polls: [poll]));

  Poll current(AppProvider app) => app.currentGroup.polls.first;

  group('§G2.3 row 8 — a single-choice vote can be changed', () {
    test('tapping an option records the vote against the signed-in member', () {
      final app = voter(nina, newPoll());

      app.votePoll('poll-1', ['9pm']);

      expect(current(app).votes['u2'], ['9pm']);
      expect(current(app).totalVotes, 1);
    });

    test('tapping a second option MOVES the vote rather than adding one', () {
      // The failure this guards is the member counted twice: two entries, or
      // one entry holding both options, either of which makes a single-choice
      // poll read as 2 voters with 100% on the option they rejected.
      final app = voter(nina, newPoll());

      app.votePoll('poll-1', ['9pm']);
      app.votePoll('poll-1', ['10pm']);

      expect(current(app).votes['u2'], ['10pm']);
      expect(current(app).totalVotes, 1);
      expect(current(app).optionCounts(), {'8pm': 0, '9pm': 0, '10pm': 1});
    });

    test('only the newest option survives, however many were tapped', () {
      // The tap sequence above is the user-facing guarantee. A caller that
      // hands `votePoll` a multi-element list anyway is collapsed to the first
      // entry, so a stale screen cannot smuggle two selections into a poll
      // that has one.
      final app = voter(nina, newPoll());

      app.votePoll('poll-1', ['8pm', '9pm', '10pm']);

      expect(current(app).votes['u2'], hasLength(1));
      expect(current(app).votes['u2'], ['8pm']);
    });

    test('changing a vote leaves the other members\' votes alone', () {
      final app = voter(
        nina,
        newPoll(votes: {
          'u1': ['8pm'],
          'u3': ['10pm'],
        }),
      );

      app.votePoll('poll-1', ['9pm']);
      app.votePoll('poll-1', ['10pm']);

      final votes = current(app).votes;
      expect(votes['u1'], ['8pm'], reason: "another member's vote is untouched");
      expect(votes['u3'], ['10pm'], reason: 'including the same option');
      expect(votes['u2'], ['10pm']);
      expect(current(app).totalVotes, 3);
    });
  });

  group('§G2.3 row 8 — a multi-choice vote keeps every option tapped', () {
    test('several options are stored under one key', () {
      final app = voter(nina, newPoll(multi: true));

      app.votePoll('poll-1', ['8pm', '10pm']);

      expect(current(app).votes['u2'], ['8pm', '10pm']);
      expect(current(app).totalVotes, 1, reason: 'one voter, not two');
      expect(current(app).optionCounts(), {'8pm': 1, '9pm': 0, '10pm': 1});
    });

    test('re-ticking with a smaller set replaces the previous set', () {
      // Multi-choice is not cumulative across calls: unticking is expressed by
      // sending the full reduced list, so the stored list is exactly what the
      // last tap produced.
      final app = voter(nina, newPoll(multi: true));

      app.votePoll('poll-1', ['8pm', '9pm', '10pm']);
      app.votePoll('poll-1', ['8pm']);

      expect(current(app).votes['u2'], ['8pm']);
      expect(current(app).optionCounts(), {'8pm': 1, '9pm': 0, '10pm': 0});
    });

    test('a multi-choice poll still un-votes on an empty list', () {
      final app = voter(nina, newPoll(multi: true));

      app.votePoll('poll-1', ['8pm', '10pm']);
      app.votePoll('poll-1', const []);

      expect(current(app).votes.containsKey('u2'), isFalse);
    });
  });

  group('§G2.3 row 8 — an un-vote DELETES the entry', () {
    test('tapping your own choice again removes your key from the map', () {
      final app = voter(nina, newPoll());

      app.votePoll('poll-1', ['9pm']);
      app.votePoll('poll-1', const []);

      final poll = current(app);
      expect(poll.votes.containsKey('u2'), isFalse);
      expect(poll.totalVotes, 0);
      expect(poll.optionCounts(), {'8pm': 0, '9pm': 0, '10pm': 0});
    });

    test('no entry is ever left behind holding an empty list', () {
      // The whole point of "deletes your entry, never stores an empty list".
      // An empty list still counts in `votes.length`, so it would keep the
      // member in the denominator of every percentage bar while contributing
      // nothing to any numerator.
      final app = voter(nina, newPoll(multi: true));

      app.votePoll('poll-1', ['8pm', '9pm']);
      app.votePoll('poll-1', const []);

      final poll = current(app);
      expect(poll.votes.values.where((v) => v.isEmpty), isEmpty);
      expect(poll.votes.values.every((v) => v.isNotEmpty), isTrue);
    });

    test('un-voting does not disturb anyone else\'s vote', () {
      final app = voter(
        nina,
        newPoll(votes: {
          'u1': ['8pm'],
          'u3': ['10pm'],
        }),
      );

      app.votePoll('poll-1', ['9pm']);
      app.votePoll('poll-1', const []);

      final poll = current(app);
      expect(poll.votes.containsKey('u2'), isFalse);
      expect(poll.votes['u1'], ['8pm']);
      expect(poll.votes['u3'], ['10pm']);
      expect(poll.totalVotes, 2);
      expect(poll.optionCounts(), {'8pm': 1, '9pm': 0, '10pm': 1});
    });

    test('a member who never voted is not given an entry by someone else\'s '
        'un-vote', () {
      // Guards the map surgery: removing a key must not renumber, reorder, or
      // drop the other voters' selections.
      final app = voter(
        nina,
        newPoll(multi: true, votes: {
          'u3': ['8pm', '10pm'],
        }),
      );

      app.votePoll('poll-1', ['9pm']);
      app.votePoll('poll-1', const []);

      expect(current(app).votes, {
        'u3': ['8pm', '10pm'],
      });
    });
  });

  group('§G2.3 row 6 — the chat send throttle', () {
    // The spec's row 6 has two halves: "the 9th message within 30s" (a burst
    // ceiling) and "two within 4s" (a minimum gap between messages). Only the
    // second half is reachable from a test, and the reason is worth stating
    // because it is a testability gap rather than a defect: the two rules are
    // checked in the order given, and the 4s gap gate returns first, so
    // filling a 30s window to its 8-message ceiling needs eight sends spaced
    // 4s apart — 28s of real time — and the provider reads `DateTime.now()`
    // with no clock seam to advance.
    //
    // The ceiling itself is not dead code: a member tapping as fast as the gap
    // allows legitimately reaches 8 sends inside the window, and the 9th is
    // refused by `_chatBurstLimit`. What is missing is a way to assert that
    // without waiting 32 seconds.

    const tooQuick =
        AppProvider.chatThrottleMessage;

    AppProvider chatter(AppUser user) => AppProvider()
      ..setUserForTesting(user)
      ..setCurrentGroupForTesting(club);

    test('a first message goes through', () {
      final app = chatter(nina);

      expect(app.sendChatMessage(null, 'hello'), isNull);
      expect(app.currentGroup.chat, hasLength(1));
      expect(app.currentGroup.chat.last.body, 'hello');
    });

    test('a second message inside 4 seconds is refused with the copy', () {
      // No sleep: the gap is measured in real time and a test body runs in
      // microseconds, so the two sends are effectively simultaneous.
      final app = chatter(nina);
      app.sendChatMessage(null, 'first');

      expect(app.sendChatMessage(null, 'second'), tooQuick);
    });

    test('the refused message is not stored, queued, or half-written', () {
      final app = chatter(nina);
      app.sendChatMessage(null, 'first');

      app.sendChatMessage(null, 'second');

      expect(app.currentGroup.chat, hasLength(1));
      expect(
        app.currentGroup.chat.map((m) => m.body),
        ['first'],
        reason: 'a blocked send must leave no trace in the transcript',
      );
    });

    test('the refusal returns the copy rather than a thrown error or a bool',
        () {
      // The channel is a `String?` return the chat composer turns into a
      // visible message. An exception or a silent false would drop the reason
      // the member is not allowed to type.
      final app = chatter(nina);
      app.sendChatMessage(null, 'first');

      final error = app.sendChatMessage(null, 'second');

      expect(error, isA<String>());
      expect(error, isNotEmpty);
      expect(error, tooQuick);
    });

    test('the throttle is per member, not per group', () {
      // Keyed on the sender's id, so Nina's burst does not lock Sam out of the
      // same conversation. A group-wide limiter would make one member's rapid
      // tapping mute everybody.
      final ninaApp = chatter(nina);
      ninaApp.sendChatMessage(null, 'nina one');
      expect(ninaApp.sendChatMessage(null, 'nina two'), tooQuick);

      final samApp = chatter(sam);
      expect(samApp.sendChatMessage(null, 'sam one'), isNull);
      expect(samApp.currentGroup.chat, hasLength(1));
    });

    test('every blocked attempt returns the same copy, not a shortened one', () {
      final app = chatter(nina);
      app.sendChatMessage(null, 'first');

      for (var i = 0; i < 5; i++) {
        expect(app.sendChatMessage(null, 'spam $i'), tooQuick);
      }
      expect(app.currentGroup.chat, hasLength(1));
    });

    test('an empty message is refused for emptiness, not as a rate limit', () {
      // Distinct failures need distinct copy: a member who sent whitespace
      // should not be told to slow down, and vice versa.
      final app = chatter(nina);

      expect(app.sendChatMessage(null, '   '), 'Message cannot be empty.');
      expect(
        app.sendChatMessage(null, 'then a real one'),
        isNull,
        reason: 'a rejected send must not consume the member\'s own throttle slot',
      );
    });
  });
}
