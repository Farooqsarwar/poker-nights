import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/repositories/firebase_repository.dart';

/// The two documents a game owns OUTSIDE `groups/{gid}`, which a recursive
/// group delete cannot reach by walking the group document.
///
/// There is no Firestore seam in this project to test `deleteGroupRecursive`
/// against — no `fake_cloud_firestore`, no injectable `FirebaseFirestore`, and
/// no test in `test/` that constructs one — so the reference set is pinned
/// where it is actually decided: in the pure function that names it. What is
/// deliberately NOT asserted here is the group-internal walk, which is built
/// from live collection queries and cannot be exercised without a Firestore
/// double.
///
/// The two safety properties that live in the function body rather than in the
/// reference set — the group document is queued last, and no hand-named row is
/// deleted without a presence check — are pinned against the source text at the
/// end of this file. That is a weaker instrument than a behavioural test and is
/// labelled as such; it is here because the failure it guards against (a rules
/// error denying a whole chunk, leaving the group half-deleted) is invisible
/// until production.
Set<String> _paths(List<ExternalRef> refs) =>
    refs.map((r) => '${r.collection}/${r.id}').toSet();

List<ExternalRef> _refs({
  String gameId = 'game-1',
  String? publicCode,
  String? tvCode,
}) =>
    FirebaseRepository.externalGameRefs(
      gameId: gameId,
      publicCode: publicCode,
      tvCode: tvCode,
    );

void main() {
  group('every world-readable row a game leaves behind is named', () {
    test('the projection and both codes', () {
      expect(
        _paths(_refs(publicCode: 'ABC123', tvCode: 'TV7890')),
        {'publicGames/game-1', 'joinCodes/ABC123', 'joinCodes/TV7890'},
      );
    });

    test('the projection is named even with no codes at all', () {
      // E7 releases a game's projection and both codes when it completes or is
      // cancelled, and a game stored before codes existed has neither. The
      // projection is the leak that stays readable to the whole world, so it is
      // the one ref that must never depend on a code being present.
      expect(_paths(_refs()), {'publicGames/game-1'});
    });

    test('one code without the other', () {
      expect(
        _paths(_refs(publicCode: 'ABC123')),
        {'publicGames/game-1', 'joinCodes/ABC123'},
      );
      expect(
        _paths(_refs(tvCode: 'TV7890')),
        {'publicGames/game-1', 'joinCodes/TV7890'},
      );
    });
  });

  group('a blank code never becomes a document id', () {
    // `collection('')` addresses the COLLECTION, not a document, so a ref built
    // from an empty code is not a delete request at all — it is a request to
    // delete something that is not there, which is exactly the case the rules
    // refuse.
    for (final blank in [null, '', '   ']) {
      test('publicCode ${blank == null ? 'null' : '"$blank"'}', () {
        final refs = _refs(publicCode: blank, tvCode: 'TV7890');
        expect(_paths(refs), {'publicGames/game-1', 'joinCodes/TV7890'});
        expect(refs.every((r) => r.id.isNotEmpty), isTrue);
      });

      test('tvCode ${blank == null ? 'null' : '"$blank"'}', () {
        final refs = _refs(publicCode: 'ABC123', tvCode: blank);
        expect(_paths(refs), {'publicGames/game-1', 'joinCodes/ABC123'});
        expect(refs.every((r) => r.id.isNotEmpty), isTrue);
      });
    }

    test('no ref anywhere has an empty id', () {
      final refs = _refs(gameId: '  ', publicCode: '', tvCode: ' ');
      expect(refs, isEmpty);
    });
  });

  group('the code is addressed the way it was written', () {
    test('trimmed and upper-cased, matching upsertGameCodes', () {
      // `upsertGameCodes` stores `game.publicCode.toUpperCase()`. Addressing a
      // legacy document that held a lower-case or padded value without
      // normalising would aim the delete at a document that does not exist.
      expect(
        _paths(_refs(publicCode: '  abc123 ', tvCode: 'tv7890')),
        {'publicGames/game-1', 'joinCodes/ABC123', 'joinCodes/TV7890'},
      );
    });

    test('a game id is used as stored, not re-cased', () {
      // Game ids are `Formatters.secureId('game')`, which is mixed case, and
      // `publishPublicProjections` keys the projection by the id verbatim.
      expect(_paths(_refs(gameId: 'game-AbC123')), contains('publicGames/game-AbC123'));
    });
  });

  group('no redundant work in the batch', () {
    test('a game whose public and TV codes are the same value is one ref', () {
      // One namespace, one document — E7. Deleting `joinCodes/{code}` twice
      // would have the rule evaluated twice for the same document.
      final refs = _refs(publicCode: 'SAME01', tvCode: 'same01');
      expect(_paths(refs), {'publicGames/game-1', 'joinCodes/SAME01'});
      expect(refs.length, 2);
    });

    test('the two codes stay distinct when they are', () {
      expect(
        _refs(publicCode: 'ABC123', tvCode: 'TV7890').length,
        3,
      );
    });
  });

  group('two games in one group never collide', () {
    test('their external rows are disjoint apart from a shared code', () {
      // A shared code is a real collision and can only happen if a code was
      // re-rolled onto another game; the same document is then deleted once,
      // which is what a Set of paths in the caller produces.
      final a = _paths(_refs(gameId: 'g-a', publicCode: 'AAA111', tvCode: 'TVAAAA'));
      final b = _paths(_refs(gameId: 'g-b', publicCode: 'BBB222', tvCode: 'TVBBBB'));
      expect(a.intersection(b), isEmpty);
      expect(a.length, 3);
      expect(b.length, 3);
    });
  });

  group('the batch cannot deny itself', () {
    // Everything here is a source assertion, not a behavioural one. These
    // properties are decided inside `deleteGroupRecursive`, which cannot run
    // without Firestore, and each is a property of the ORDER of the writes
    // rather than of any value.
    String body() {
      final source =
          File('lib/repositories/firebase_repository.dart').readAsStringSync();
      final start = source.indexOf('Future<void> deleteGroupRecursive(');
      expect(start, greaterThan(-1), reason: 'the walk was renamed or removed');
      // Everything in the method body is indented deeper than the method, so the
      // first line of exactly two spaces then a brace after the signature is the
      // end of THIS method. A nested local function closing at four spaces does
      // not match, which is the case this would otherwise trip on.
      //
      // The line ending is matched rather than assumed: this checkout is CRLF, so
      // a literal '\n  }\n' finds nothing there and every test in this group
      // would report "the walk was renamed or removed" on Windows while passing
      // on a machine with LF -- a false alarm about the production file.
      final close = RegExp(r'\r?\n  \}\r?\n').firstMatch(source.substring(start));
      expect(close, isNotNull, reason: 'the method body was never closed');
      return source.substring(start, start + close!.start);
    }

    test('the group document is the LAST delete queued', () {
      // The three rules this walk runs under all read `groups/{gid}`:
      //   publicGames/{gameId} -> isGroupOwner(resource.data.gid)
      //   joinCodes/{code}     -> isGroupOwner(resource.data.gid)
      //                              || uid == resource.data.ownerId
      //   groups/{gid}         -> isGroupOwner(gid)
      // So every write authorises only while the group document still exists.
      // Firestore evaluates a batch against the state *before* it commits, which
      // is what makes the last chunk safe: `groups/{gid}` is still there while
      // its own delete — and any projection or code delete sharing that chunk —
      // is being judged. It is queued last so that it lands in the LAST chunk,
      // which means every earlier chunk is committed while the group document
      // is intact. Move it up and a group of more than 500 documents deletes its
      // roster and then refuses its own group document.
      final src = body();
      final lastAdd = src.lastIndexOf('deletes.add(');
      expect(lastAdd, greaterThan(-1));
      expect(
        src.substring(lastAdd),
        startsWith('deletes.add(groupRef)'),
        reason: 'nothing may be queued after the group document',
      );
    });

    test('the rows outside the group are queued before it, and checked', () {
      // `_existingRefs` reads each hand-named row first. A delete of a document
      // that is NOT there still evaluates its rule, with `resource` null, and
      // `resource.data.gid` on a null resource is a rules error — so the write is
      // denied, and one denied write fails the whole chunk it is in.
      //
      // A missing row is not an exotic case, it is an expected one, and for two
      // separate reasons. E7 releases a completed game's projection and both its
      // codes, and the group's own invite code is whatever the caller's copy of
      // the group says it is — `deleteGroup` passes `_currentGroup.joinCode`,
      // which is stale the moment a re-roll happened on another device, and the
      // row the re-roll deleted is the one the old code names.
      final src = body();
      expect(src, contains('_existingRefs'));
      expect(
        src.indexOf('_existingRefs'),
        lessThan(src.lastIndexOf('deletes.add(groupRef)')),
      );
      expect(
        RegExp(r"deletes\.add\(\s*_db\.collection\('").hasMatch(src),
        isFalse,
        reason: 'a row outside the group must go through the presence check, '
            'not be queued blind',
      );
    });

    test('a code two rows name is queued once', () {
      // Two games can hold the same code if one was re-rolled onto the other,
      // and a game code can collide with the group's own invite code. Both name
      // one document, so one delete — the rule is evaluated per write, and a
      // duplicate is a second evaluation of a request already made.
      expect(body(), contains('external.toSet()'));
    });

    test('the chunk loop preserves the order the list was built in', () {
      // `deletes.skip(i).take(500)` walks one ordered list front to back, so the
      // position of the group document inside it is the position it has in the
      // final chunk. Sorting, reversing or re-adding here would silently move it.
      final src = body();
      expect(src, contains('deletes.skip(i).take(500)'));
      expect(
        RegExp(r'deletes\.(sort|reversed|shuffle)').hasMatch(src),
        isFalse,
      );
    });

    test('the request queue is queried, because it is not under the group', () {
      // `requests/{gameId}/items/{reqId}` is the one top-level collection keyed
      // by GAME that the group-document walk cannot reach, and each row is a
      // guest slot claim or a member's rebuy request carrying the requester's
      // name. An orphaned queue is personal data about a group that no longer
      // exists, readable by the person who made the claim and by nobody who
      // could now clear it.
      final src = body();
      expect(
        src,
        contains(".collection('requests')"),
        reason: 'the top-level request queue is never enumerated',
      );
      expect(
        src,
        contains("where('gid', isEqualTo: gid)"),
        reason: 'the query must be constrained to this group',
      );
      // Constrained on gid, which is what makes the per-document
      // `allow list: if isGroupAdmin(gid)` authorise the read: the rule is
      // evaluated on each returned document, and the caller is the owner.
      expect(src, contains("addAll(requestDoc.reference, 'items')"));
    });

    test('pendingInvites is left alone, and says why in the source', () {
      // Deliberate, not an oversight. Every row's read rule is
      // `resource.data.uid == request.auth.uid`, so a `where('gid', ...)` can
      // only ever return the CALLER's own invitations: the owner cannot
      // enumerate, let alone delete, invitations the admin sent to somebody
      // else. There is no client-side fix — it needs the rows to live under
      // `groups/{gid}` or a server-side sweep.
      //
      // Pinned because the residue is user-visible (a dead invitation pointing
      // at a group that no longer exists) and somebody will otherwise read the
      // absence as a bug and "fix" it with a query that returns nothing.
      final src = body();
      expect(
        RegExp(r"collection\('pendingInvites'\)").hasMatch(src),
        isFalse,
        reason: 'a pendingInvites query would silently return only the '
            'caller\'s own rows',
      );
      expect(
        src,
        contains('pendingInvites'),
        reason: 'the reason must be written down where the gap is',
      );
    });
  });
}
