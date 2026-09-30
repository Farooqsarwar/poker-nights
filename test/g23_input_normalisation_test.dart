import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/utils/sanitization.dart';

/// §G2.3 row 7 and §E17 row 65 — the input normalisation pipeline.
///
/// §E16 gives the pipeline in full, as one ordered list:
///
///   "**Sanitising text** (names, chat, polls, group names): decode entities,
///   remove dangerous tags, strip remaining HTML, collapse whitespace, trim,
///   truncate to the field's limit (names 1–40, poll question 1–120, option
///   1–60, chat 1–1,000)."
///
/// §E17 row 65 lists the same pipeline with "none yet" against T63, and names
/// T63 as testing *display escaping only* — so the pipeline itself is the gap
/// this file closes.
///
/// The ordering is the substance, not an implementation detail. Decoding has to
/// happen BEFORE tag-stripping, or `&lt;script&gt;` survives as inert-looking
/// text and is decoded into a live tag by whatever renders it later. Each step
/// is asserted against a string that only that step can produce, so a
/// regression that merely moves a step will fail rather than quietly still
/// produce "clean" output.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => RecoveryService.enabled = false);
  tearDown(() => RecoveryService.enabled = true);

  group('§E17 row 65 — the pipeline, in order', () {
    test('entities are decoded, not merely stripped around', () {
      // The order that matters: if tags were stripped first, this would come
      // back as the literal text "&lt;b&gt;" and a later decode — by a share
      // card, a notification, anything — would turn it into markup.
      expect(Sanitization.sanitize('&lt;b&gt;hi&lt;/b&gt;'), 'hi');
      expect(Sanitization.sanitize('5 &lt; 6'), '5 < 6');
      expect(Sanitization.sanitize('&amp;'), '&');
      expect(Sanitization.sanitize('&quot;quoted&quot;'), '"quoted"');
      expect(Sanitization.sanitize('&#39;apostrophe&#39;'), "'apostrophe'");
    });

    test('a dangerous tag with content is removed whole, content included', () {
      // Not just the brackets: `<script>steal()</script>` stripped to
      // `steal()` would leave the payload behind as visible text.
      expect(
        Sanitization.sanitize('hi <script>steal()</script> there'),
        'hi there',
      );
      expect(
        Sanitization.sanitize('<style>body{display:none}</style>ok'),
        'ok',
      );
      expect(
        Sanitization.sanitize('<iframe src="evil"></iframe>ok'),
        'ok',
      );
      expect(
        Sanitization.sanitize('<object data="x"><embed src="y"></object>ok'),
        'ok',
      );
    });

    test('the tag removal is case-insensitive', () {
      expect(Sanitization.sanitize('<SCRIPT>steal()</SCRIPT>ok'), 'ok');
      expect(Sanitization.sanitize('<ScRiPt>steal()</ScRiPt>ok'), 'ok');
    });

    test('remaining HTML is stripped rather than escaped', () {
      // §E16 says "strip remaining HTML", so the stored value is plain text
      // with no markup in it at all — not `&lt;b&gt;`.
      expect(Sanitization.sanitize('<b>bold</b>'), 'bold');
      expect(Sanitization.sanitize('<a href="x">link</a>'), 'link');
      expect(Sanitization.sanitize('a<br>b'), 'ab');
      expect(
        Sanitization.sanitize('<div class="x">text</div>'),
        'text',
      );
    });

    test('whitespace is collapsed and the result is trimmed', () {
      // Both halves. Collapsing without trimming leaves one leading space,
      // which then becomes the first character of a name in a list.
      expect(Sanitization.sanitize('a    b'), 'a b');
      expect(Sanitization.sanitize('a\n\n\nb'), 'a b');
      expect(Sanitization.sanitize('a\t\tb'), 'a b');
      expect(Sanitization.sanitize('   padded   '), 'padded');
      expect(Sanitization.sanitize('\n\n  padded \n'), 'padded');
    });

    test('a decoded &nbsp; collapses with its neighbours, not left as a space run',
        () {
      // &nbsp; decodes to a space, which the collapse step then has to see. If
      // the decode ran after the collapse, the non-breaking space would survive
      // and render as an unbreakable gap in the middle of a name.
      expect(Sanitization.sanitize('Alex&nbsp;&nbsp;&nbsp;M'), 'Alex M');
    });

    test('a string that is entirely markup or whitespace sanitises to empty',
        () {
      // The empty result is what the caller's own guard keys on, so it has to
      // be genuinely empty rather than a run of spaces.
      expect(Sanitization.sanitize('   '), '');
      expect(Sanitization.sanitize('<br>'), '');
      expect(Sanitization.sanitize('<script>x()</script>'), '');
      expect(Sanitization.sanitize('\n\t '), '');
    });
  });

  group('§E16 — each field truncates to its own limit', () {
    test('the four limits are the spec\'s numbers', () {
      expect(Sanitization.maxNameLength, 40);
      expect(Sanitization.maxPollQuestionLength, 120);
      expect(Sanitization.maxPollOptionLength, 60);
      expect(Sanitization.maxChatLength, 1000);
    });

    test('a name is cut at 40 characters', () {
      expect(Sanitization.sanitizeName('x' * 60).length, 40);
      expect(Sanitization.sanitizeName('x' * 39).length, 39);
      expect(Sanitization.sanitizeName('x' * 40).length, 40);
    });

    test('a poll question is cut at 120 and an option at 60', () {
      expect(Sanitization.sanitizePollQuestion('q' * 200).length, 120);
      expect(Sanitization.sanitizePollOption('o' * 200).length, 60);
    });

    test('chat is cut at 1,000', () {
      expect(Sanitization.sanitizeChat('c' * 2000).length, 1000);
    });

    test('truncation happens AFTER sanitising, not before', () {
      // The ordering again. Cutting to 40 first and sanitising after would let
      // a name whose first 40 characters are `<b>` produce a stored value that
      // is 36 visible characters with four of markup gone.
      final raw = '<b>${'a' * 60}</b>';
      final name = Sanitization.sanitizeName(raw);
      expect(name, 'a' * 40);
      expect(name, isNot(contains('<')));
    });

    test('a name that is all markup becomes empty rather than 40 spaces', () {
      final name = Sanitization.sanitizeName('<b></b>' * 30);
      expect(name, isEmpty);
    });
  });

  group('§E16 — the pipeline is applied on the way IN, not on the way out', () {
    // These drive the provider, because a correct `Sanitization` that nothing
    // calls satisfies nothing. `sendChatMessage` and `createPoll` are the two
    // write paths the spec names ("Any name/chat/poll/group-name entry",
    // §E17 row 65).

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

    const member = AppUser(
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

    final club = Group(
      id: 'g1',
      name: 'Friday Poker Club',
      joinCode: 'FP2608',
      ownerId: 'u1',
      members: const [host, member],
      games: const [],
      chat: const [],
      polls: const [],
      notifications: const [],
    );

    AppProvider provider({AppUser user = member}) =>
        AppProvider()
          ..setUserForTesting(user)
          ..setCurrentGroupForTesting(club);

    ChatMessage? lastMessage(AppProvider app) => app.currentGroup.chat.isEmpty
        ? null
        : app.currentGroup.chat.last;

    test('a chat message is stored sanitised', () {
      final app = provider();

      final error = app.sendChatMessage(null, '<b>bold</b>   and  <i>italic</i>');

      expect(error, isNull);
      final stored = lastMessage(app)!;
      expect(stored.body, 'bold and italic');
      expect(stored.body, isNot(contains('<')));
    });

    test('a chat message that is only markup is refused, not stored blank', () {
      final app = provider();

      final error = app.sendChatMessage(null, '<script>x()</script>');

      expect(error, 'Message cannot be empty.');
      expect(app.currentGroup.chat, isEmpty);
    });

    test('CURRENT BEHAVIOUR (not what §E16 asks for): an over-long chat message '
        'is silently truncated to 1,000, not refused', () {
      // §E16's pipeline ends at "truncate to the field's limit", so truncation
      // is the specified outcome and this part is satisfied.
      //
      // What is NOT specified is the provider's own refusal copy.
      // `sendChatMessage` sanitises with `sanitizeChat`, which already cuts to
      // 1,000, and only then tests `sanitized.length > maxChatMessageLength`
      // where `maxChatMessageLength` is the same 1,000. The comparison can
      // never be true, so "Message is too long - maximum 1000 characters." is
      // unreachable and a 5,000-character paste is accepted with 4,000
      // characters discarded and no indication to the sender.
      //
      // The test name says so rather than pinning the silence as correct: the
      // user-visible half (a message silently losing four-fifths of itself)
      // is the defect, not the truncation.
      final app = provider();

      final error = app.sendChatMessage(null, 'c' * 5000);

      expect(error, isNull, reason: 'the refusal branch is unreachable');
      expect(lastMessage(app)!.body.length, 1000);
      // Defensible and worth keeping: the stored value is still clean text.
      expect(lastMessage(app)!.body, isNot(contains('<')));
    });

    test('a poll question and its options are stored sanitised', () {
      final app = provider(user: host);

      final error = app.createPoll(
        '<b>What time?</b>',
        ['<i>8pm</i>', '  9pm  ', '<script>x()</script>'],
      );

      expect(error, isNull);
      final poll = app.currentGroup.polls.last;
      expect(poll.question, 'What time?');
      expect(poll.options, ['8pm', '9pm']);
      // The third option was markup only, so it sanitised to nothing and was
      // dropped — an option that sanitises away is not an option.
      expect(poll.options.where((o) => o.isEmpty), isEmpty);
      expect(poll.options.every((o) => !o.contains('<')), isTrue);
    });

    test('a poll question that sanitises away is refused', () {
      final app = provider(user: host);

      final error = app.createPoll('<script>x()</script>', ['a', 'b']);

      expect(error, 'Poll needs a question.');
      expect(app.currentGroup.polls, isEmpty);
    });

    test('a poll option that sanitises away is refused, not silently counted',
        () {
      // Two surviving options is still below the floor of two, so the poll is
      // refused rather than filed with a question and one choice.
      final app = provider(user: host);

      final error = app.createPoll('Where?', ['<br>', '   ']);

      expect(error, 'Poll needs at least two options.');
      expect(app.currentGroup.polls, isEmpty);
    });
  });
}
