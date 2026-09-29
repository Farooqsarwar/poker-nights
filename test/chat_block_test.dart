import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/utils/model_codec.dart';

AppUser _member(String id, String name, {bool admin = false}) => AppUser(
      id: id,
      name: name,
      email: '$id@example.com',
      isAdmin: admin,
      stats: const UserStats(
        played: 0,
        wins: 0,
        podium: 0,
        avgFinish: 0,
        knockouts: 0,
      ),
    );

ChatMessage _msg(
  String id,
  String authorId,
  String authorName,
  String body,
  DateTime at,
) =>
    ChatMessage(
      id: id,
      authorId: authorId,
      authorName: authorName,
      body: body,
      timestamp: at,
      deleted: false,
    );

void main() {
  // AppProvider's constructor subscribes to a connectivity EventChannel, so a
  // plain `test()` still needs a binding for the platform-channel messenger.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Chat blocking — §E10 (3) / B4 "Block {name}"', () {
    late AppProvider app;
    late AppUser alice;
    late Group group;

    setUp(() {
      // Every provider change mirrors the live game into the device-local
      // crash-recovery store, which is one `recovery/active_game` document for
      // the whole test process; its delete-before-write step collides between
      // tests (errno 32). Nothing here is about recovery, so switch it off.
      RecoveryService.enabled = false;
      app = AppProvider();
      alice = _member('alice', 'Alice', admin: true);
      group = const Group(
        id: 'g1',
        name: 'Test Group',
        joinCode: 'JOIN1',
        ownerId: 'alice',
        members: [],
        games: [],
        chat: [],
        polls: [],
        notifications: [],
      );
      app.setUserForTesting(alice);
      app.setCurrentGroupForTesting(group);
    });

    tearDown(() => RecoveryService.enabled = true);

    void chatOf(List<ChatMessage> messages) {
      app.setCurrentGroupForTesting(group.copyWith(chat: messages));
    }

    test('a blocked author vanishes from the feed, and comes back on unblock', () {
      final t0 = DateTime(2025, 1, 1, 12, 0);
      final t1 = DateTime(2025, 1, 1, 12, 1);
      final t2 = DateTime(2025, 1, 1, 12, 2);
      chatOf([
        _msg('m1', 'alice', 'Alice', 'deck is rigged', t0),
        _msg('m2', 'bob', 'Bob', 'buy my chips', t1),
        _msg('m3', 'charlie', 'Charlie', 'nice game', t2),
      ]);

      expect(app.blockUser('bob'), isTrue);
      expect(app.isBlocked('bob'), isTrue);
      expect(
        app.visibleGroupChat().map((m) => m.id),
        ['m1', 'm3'],
        reason: 'only Bob\'s message is hidden, in place',
      );

      expect(app.unblockUser('bob'), isTrue);
      expect(
        app.visibleGroupChat().map((m) => m.id),
        ['m1', 'm2', 'm3'],
        reason: 'unblocking restores the whole conversation, order kept',
      );
    });

    test('a block hides only that author, and never deletes anything', () {
      final t = DateTime(2025, 1, 1, 12, 0);
      chatOf([
        _msg('m1', 'bob', 'Bob', 'spam', t),
        _msg('m2', 'bob', 'Bob', 'more spam', t),
        _msg('m3', 'alice', 'Alice', 'mine', t),
      ]);

      expect(app.blockUser('bob'), isTrue);

      // The filter is read-side: the group transcript is untouched, so another
      // member (and the host) still sees the same two messages, and the host's
      // Delete/Report still has something to act on.
      expect(app.currentGroup.chat.length, 3);
      expect(app.currentGroup.chat.where((m) => m.deleted), isEmpty);
      expect(
        app.visibleGroupChat().map((m) => m.id),
        ['m3'],
        reason: 'both of Bob\'s messages go, his own and everyone else\'s stay',
      );
    });

    test('ChatMessage.visibleTo is the same filter, order preserving', () {
      final t = DateTime(2025, 1, 1, 12, 0);
      final all = [
        _msg('m1', 'bob', 'Bob', 'one', t),
        _msg('m2', 'alice', 'Alice', 'two', t),
        _msg('m3', 'bob', 'Bob', 'three', t),
      ];

      expect(
        ChatMessage.visibleTo(all, const {}).map((m) => m.id),
        ['m1', 'm2', 'm3'],
        reason: 'nobody blocked: a copy of everything',
      );
      expect(
        ChatMessage.visibleTo(all, const {'bob'}).map((m) => m.id),
        ['m2'],
      );
      expect(
        ChatMessage.isVisibleTo(all.first, const {'bob'}),
        isFalse,
        reason: 'an authorless system card has a blank id and is never muted',
      );
      expect(ChatMessage.isVisibleTo(_msg('s', '', '', 'Game started', t), const {''}), isTrue);
    });

    test('a block survives the one codec in both directions', () {
      final blocked = alice.withBlocked('bob').withBlocked('charlie');
      final map = appUserToMap(blocked);

      expect(map['blockedUserIds'], ['bob', 'charlie']);
      expect(
        appUserFromMap(map).blockedUserIds,
        ['bob', 'charlie'],
        reason: '§E2 rule 1: the cloud document and the device store use the '
            'same encoding, so a restored profile has the same block list',
      );
    });

    test('a profile written before blocking existed reads back as empty', () {
      final legacy = appUserToMap(alice)..remove('blockedUserIds');

      expect(appUserFromMap(legacy).blockedUserIds, isEmpty);
      expect(appUserFromMap(legacy).isBlocked('bob'), isFalse);
    });

    test('the stored list is normalised on the way back in', () {
      final restored = alice.withBlockedList(['bob', '', 'bob', 'alice', 'charlie']);

      expect(
        restored.blockedUserIds,
        ['bob', 'charlie'],
        reason: 'blanks, duplicates and your own id are dropped, so a '
            'hand-edited document cannot leave an un-undoable state',
      );
      expect(identical(restored.withBlockedList(['bob', 'charlie']), restored), isTrue,
          reason: 'an unchanged restore writes nothing back');
    });

    test('the no-op cases report no change and keep the same instance', () {
      final user = alice.withBlocked('bob');

      expect(identical(user.withBlocked('bob'), user), isTrue,
          reason: 'already blocked');
      expect(identical(user.withBlocked(''), user), isTrue,
          reason: 'an authorless message is a system card, never a mute target');
      expect(identical(user.withBlocked('alice'), user), isTrue,
          reason: 'blocking yourself would only hide your own messages');
      expect(identical(user.withoutBlocked('charlie'), user), isTrue,
          reason: 'they were not blocked');
    });

    test('blockUser/unblockUser on the provider follow the same rules', () {
      expect(app.blockUser('bob'), isTrue);
      expect(app.blockUser('bob'), isFalse, reason: 'no duplicate write');
      expect(app.blockUser('alice'), isFalse, reason: 'not yourself');
      expect(app.blockUser(''), isFalse, reason: 'blank id');
      expect(app.unblockUser('charlie'), isFalse, reason: 'not blocked');
      expect(app.unblockUser('bob'), isTrue);
      expect(app.blockedUserIds, isEmpty);
    });

    test('a signed-out member filters nothing and blocks nothing', () {
      app.setUserForTesting(null);
      chatOf([_msg('m1', 'bob', 'Bob', 'hi', DateTime(2025, 1, 1))]);

      expect(app.blockedUserIds, isEmpty);
      expect(app.visibleGroupChat().length, 1,
          reason: '§E6 gives a guest no blocking right, so nothing is hidden');
      expect(app.blockUser('bob'), isFalse);
    });
  });
}
