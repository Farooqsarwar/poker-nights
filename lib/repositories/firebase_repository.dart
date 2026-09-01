import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';

import '../models/app_notification.dart';
import '../models/cash_game.dart';
import '../models/chip_color.dart';
import '../models/game.dart';
import '../models/group.dart';
import '../models/live_game.dart';
import '../models/table_settings.dart';
import '../models/tournament_preset.dart';
import '../models/user.dart';
import '../utils/model_codec.dart';

/// A membership row mirrored under [users/{uid}/groups/{groupId}] so the
/// sidebar can render every group without reading protected group documents.
class GroupMembership {
  const GroupMembership({
    required this.groupId,
    required this.name,
    required this.icon,
    required this.pinned,
    required this.role,
  });

  final String groupId;
  final String name;
  final String icon;
  final bool pinned;

  /// 'admin' | 'member'
  final String role;

  Map<String, dynamic> toMap() => {
        'groupId': groupId,
        'name': name,
        'icon': icon,
        'pinned': pinned,
        'role': role,
      };

  static GroupMembership fromMap(String gid, Map<String, dynamic> m) =>
      GroupMembership(
        groupId: m['groupId'] as String? ?? gid,
        name: (m['name'] as String?) ?? '',
        icon: (m['icon'] as String?) ?? '♠️',
        pinned: (m['pinned'] as bool?) ?? false,
        role: (m['role'] as String?) ?? 'member',
      );
}

/// One staged notification in a group's outbox
/// (`groups/{gid}/notifications/{id}`). Member devices mirror unseen items
/// into their own inbox — the free-plan replacement for a fan-out function.
class OutboxNotification {
  const OutboxNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.link,
    required this.audience,
    required this.timestamp,
    required this.updatedAtMillis,
  });

  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final String? link;
  final List<String>? audience;
  final DateTime timestamp;

  /// Server write time in epoch ms — the cursor the mirror advances past.
  final int updatedAtMillis;

  bool isFor(String uid) =>
      audience == null || audience!.isEmpty || audience!.contains(uid);

  AppNotification toAppNotification({required bool read}) => AppNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        link: link,
        read: read,
        timestamp: timestamp,
        audience: audience,
      );
}

/// A queued request posted by a member/guest device for the admin device to
/// consume (guest check-in, rebuy/add-on/check-in requests).
class GameRequest {
  const GameRequest({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
  });

  final String id;

  /// 'guestCheckIn' | 'rebuyReq' | 'addOnReq' | 'checkInReq'
  final String kind;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
}

/// One settled tournament from the signed-in player's point of view, mirrored
/// under `users/{uid}/results/{gameId}` so every device can aggregate the same
/// lifetime stats (played / wins / podium / avgFinish / knockouts).
class GameResultRow {
  const GameResultRow({
    required this.gameId,
    required this.groupId,
    required this.position,
    required this.playerCount,
    required this.knockouts,
    required this.finishedAt,
  });

  final String gameId;
  final String groupId;

  /// 1-based finishing position.
  final int position;
  final int playerCount;
  final int knockouts;
  final DateTime? finishedAt;

  Map<String, dynamic> toMap() => {
        'gameId': gameId,
        'groupId': groupId,
        'position': position,
        'playerCount': playerCount,
        'knockouts': knockouts,
      };

  static GameResultRow fromMap(String id, Map<String, dynamic> m) =>
      GameResultRow(
        gameId: m['gameId'] as String? ?? id,
        groupId: (m['groupId'] as String?) ?? '',
        position: (m['position'] as num?)?.toInt() ?? 0,
        playerCount: (m['playerCount'] as num?)?.toInt() ?? 0,
        knockouts: (m['knockouts'] as num?)?.toInt() ?? 0,
        finishedAt: switch (m['finishedAt']) {
          final DateTime dt => dt,
          _ => null,
        },
      );
}

/// Single Firestore access point for the whole app. Screens never touch
/// Firestore directly; [AppProvider] calls these methods optimistically after
/// mutating local state.
///
/// Echo-loop prevention: callers only apply emissions whose snapshot has
/// `metadata.hasPendingWrites == false`, so locally-sourced writes never bounce
/// back while genuine remote writes propagate normally.
class FirebaseRepository {
  FirebaseRepository._();
  static final FirebaseRepository instance = FirebaseRepository._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  fa.FirebaseAuth get _auth => fa.FirebaseAuth.instance;

  /// Stable per-install id stamped onto every write as `writerId`.
  String? _deviceId;
  String get deviceId =>
      _deviceId ??= 'dev-${DateTime.now().millisecondsSinceEpoch}';

  Map<String, dynamic> _stamp(Map<String, dynamic>? data) => {
        ...?data,
        'updatedAt': FieldValue.serverTimestamp(),
        'writerId': deviceId,
      };

  // ── Auth ───────────────────────────────────────────────────────────────────
  Stream<fa.User?> authStateChanges() => _auth.authStateChanges();
  fa.User? get currentUser => _auth.currentUser;
  String? get currentUid => _auth.currentUser?.uid;
  bool get isSignedInAsGuest => _auth.currentUser?.isAnonymous ?? false;

  Future<fa.UserCredential> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await cred.user?.updateDisplayName(name.trim());
    return cred;
  }

  Future<fa.UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  /// Upgrades the current anonymous session to a full email/password account
  /// via `linkWithCredential`, preserving the uid — so results and stats
  /// recorded as a guest stay attached to the new account (user-flow spec
  /// §6.7 "the guest result may be linked to the new account").
  Future<fa.UserCredential> linkGuestAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) {
      throw StateError('No anonymous session to upgrade.');
    }
    final credential = fa.EmailAuthProvider.credential(
      email: email.trim(),
      password: password,
    );
    final cred = await user.linkWithCredential(credential);
    await cred.user?.updateDisplayName(name.trim());
    return cred;
  }

  Future<fa.UserCredential> signInAsGuest() => _auth.signInAnonymously();

  // ── Google Sign-In (v7 API) ────────────────────────────────────────────────

  static final GoogleSignIn googleSignIn = GoogleSignIn(
    params: const GoogleSignInParams(
      clientId: 'YOUR_CLIENT_ID.apps.googleusercontent.com', // Replace with your Client ID
      clientSecret: 'YOUR_CLIENT_SECRET', // Replace with your Client Secret for desktop
      scopes: ['openid', 'profile', 'email'],
    ),
  );

  /// Initialises the [GoogleSignIn] singleton. 
  /// The new package handles initialization automatically, so this can be a no-op or silentSignIn.
  static Future<void> initGoogleSignIn() async {
    try {
      if (!kIsWeb) {
        await googleSignIn.silentSignIn();
      }
    } catch (_) {
      // Ignore
    }
  }

  /// Builds a Firebase credential from [GoogleSignInCredentials].
  Future<fa.OAuthCredential> _googleCredential(
    GoogleSignInCredentials credentials,
  ) async {
    return fa.GoogleAuthProvider.credential(
      idToken: credentials.idToken,
      accessToken: credentials.accessToken,
    );
  }

  /// Signs in (or creates) a Firebase account via Google OAuth. Returns
  /// `null` when the user cancels the flow.
  Future<fa.UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        return await _auth.signInWithPopup(fa.GoogleAuthProvider());
      } else {
        final credentials = await googleSignIn.signIn();
        if (credentials == null) return null;
        final credential = await _googleCredential(credentials);
        return _auth.signInWithCredential(credential);
      }
    } catch (e) {
      debugPrint('signInWithGoogle failed: $e');
      return null;
    }
  }

  /// Signs in to Firebase with existing credentials.
  Future<fa.UserCredential?> signInWithGoogleCredentials(GoogleSignInCredentials credentials) async {
    try {
      final credential = await _googleCredential(credentials);
      return _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint('signInWithGoogleCredentials failed: $e');
      return null;
    }
  }

  /// Upgrades the current anonymous session to a Google-linked account.
  /// Preserves the uid so guest stats/results carry over.
  Future<fa.UserCredential?> linkGuestWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) {
      throw StateError('No anonymous session to upgrade.');
    }
    try {
      if (kIsWeb) {
        return await user.linkWithPopup(fa.GoogleAuthProvider());
      } else {
        final credentials = await googleSignIn.signIn();
        if (credentials == null) return null;
        final credential = await _googleCredential(credentials);
        return user.linkWithCredential(credential);
      }
    } catch (e) {
      debugPrint('linkGuestWithGoogle failed: $e');
      return null;
    }
  }

  /// Signs out from Firebase **and** clears the Google Sign-In session so the
  /// next `signInWithGoogle()` call always shows the account chooser.
  Future<void> signOutWithGoogle() async {
    await googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() => _auth.signOut();

  /// Deletes the profile doc, membership mirrors and rows, then the auth user.
  /// Throws [fa.FirebaseException] code `requires-recent-login` when the
  /// caller must re-authenticate first.
  Future<void> deleteAccount() async {
    final uid = currentUid;
    if (uid == null) return;
    final userDoc = _db.collection('users').doc(uid);

    final memberships = await userDoc.collection('groups').get();
    final batch = _db.batch();
    for (final m in memberships.docs) {
      batch.delete(m.reference);
      batch.delete(
          _db.collection('groups').doc(m.id).collection('members').doc(uid));
    }
    for (final sub in const ['presets', 'chipSets', 'notifications']) {
      final docs = await userDoc.collection(sub).get();
      for (final d in docs.docs) {
        batch.delete(d.reference);
      }
    }
    batch.delete(userDoc);
    await batch.commit();
    await _auth.currentUser?.delete();
  }

  // ── Users ──────────────────────────────────────────────────────────────────
  /// Creates the profile doc on first sign-in, optionally seeding starter
  /// presets / chip set so a fresh account is immediately usable. Existing
  /// profiles only get their name/email refreshed.
  Future<void> ensureUserDoc({
    required String uid,
    required String name,
    required String email,
    List<TournamentPreset> starterPresets = const [],
    ({String id, String name, List<ChipColor> chips})? starterChipSet,
  }) async {
    final ref = _db.collection('users').doc(uid);
    final emailLower = email.trim().toLowerCase();
    final snap = await ref.get();
    if (!snap.exists) {
      final batch = _db.batch();
      batch.set(ref, _stamp({
        'name': name,
        'email': email,
        'emailLower': emailLower,
        'stats': userStatsToMap(const UserStats(
            played: 0, wins: 0, podium: 0, avgFinish: 0, knockouts: 0)),
        'prefs': <String, dynamic>{},
        'createdAt': FieldValue.serverTimestamp(),
      }));
      if (emailLower.isNotEmpty) {
        // Public email→uid index for the admin "add member by email" flow.
        batch.set(_db.collection('emailIndex').doc(emailLower),
            {'uid': uid, 'name': name, 'emailLower': emailLower});
      }
      for (final p in starterPresets) {
        batch.set(
            ref.collection('presets').doc(p.id), tournamentPresetToMap(p));
      }
      if (starterChipSet != null) {
        batch.set(ref.collection('chipSets').doc(starterChipSet.id), {
          'name': starterChipSet.name,
          'chips': [
            for (final c in starterChipSet.chips) chipColorToMap(c),
          ],
        });
      }
      await batch.commit();
    } else {
      // The doc already exists — DO NOT overwrite the stored display name with
      // the caller's fallback (`fbUser.displayName ?? 'Player'`), which is what
      // made every login reset the name to "Player". Only keep the email fields
      // in sync, and only when they actually changed.
      final data = Map<String, dynamic>.from(snap.data() ?? const {});
      final storedName = (data['name'] as String?) ?? name;
      if ((data['emailLower'] as String?) != emailLower && emailLower.isNotEmpty) {
        await ref.set(
            _stamp({'email': email, 'emailLower': emailLower}),
            SetOptions(merge: true));
      }
      if (emailLower.isNotEmpty) {
        await _db.collection('emailIndex').doc(emailLower).set(
          {'uid': uid, 'name': storedName, 'emailLower': emailLower},
          SetOptions(merge: true),
        );
      }
    }
  }

  Future<AppUser?> loadUser(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    final data = Map<String, dynamic>.from(snap.data()!);
    return AppUser(
      id: uid,
      name: (data['name'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      isAdmin: false,
      stats: data['stats'] == null
          ? const UserStats(
              played: 0, wins: 0, podium: 0, avgFinish: 0, knockouts: 0)
          : userStatsFromMap(Map<String, dynamic>.from(data['stats'] as Map)),
    );
  }

  Future<void> updateUserProfile(String uid, {String? name, String? email}) =>
      _db.collection('users').doc(uid).set(
            _stamp({
              'name': ?name,
              'email': ?email,
              if (email != null) 'emailLower': email.trim().toLowerCase(),
            }),
            SetOptions(merge: true),
          );

  Future<void> saveUserPref(String uid, String key, Object? value) => _db
      .collection('users').doc(uid)
      .set(_stamp({'prefs': {key: value}}), SetOptions(merge: true));

  /// Reads the stored per-user preferences map (`users/{uid}.prefs`).
  Future<Map<String, dynamic>> loadUserPrefs(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    if (!snap.exists) return const {};
    final prefs = snap.data()!['prefs'];
    return prefs is Map ? Map<String, dynamic>.from(prefs) : const {};
  }

  /// Persists the signed-in player's own result for a settled tournament.
  /// Doc id is the gameId so re-writes are idempotent.
  Future<void> saveGameResult(
    String uid,
    String gameId,
    GameResultRow row,
  ) =>
      _db.collection('users').doc(uid).collection('results').doc(gameId).set(
            _stamp({...row.toMap(), 'finishedAt': FieldValue.serverTimestamp()}),
          );

  /// Live stream of every result this player has recorded — the source of
  /// truth for lifetime stats.
  Stream<List<GameResultRow>> resultsStream(String uid) => _db
      .collection('users').doc(uid).collection('results')
      .snapshots()
      .map((s) => [
            for (final d in s.docs)
              GameResultRow.fromMap(d.id, Map<String, dynamic>.from(d.data())),
          ]);

  /// Mirrors a compact stats summary onto the caller's own roster row
  /// (`groups/{gid}/members/{uid}`) so other members' devices can display it
  /// without reading private profile data.
  Future<void> saveMemberStats(String gid, String uid, UserStats stats) =>
      _db.collection('groups').doc(gid).collection('members').doc(uid).set(
            {'stats': userStatsToMap(stats)},
            SetOptions(merge: true),
          );

  // ── Groups ─────────────────────────────────────────────────────────────────
  DocumentReference userGroupIndexRef(String uid, String gid) =>
      _db.collection('users').doc(uid).collection('groups').doc(gid);

  /// Creates the group doc, owner membership row, the owner's mirror index
  /// entry and the join-code lookup entry in one atomic batch.
  Future<void> createGroup(Group group, AppUser owner) async {
    final gid = group.id;
    final batch = _db.batch();

    final groupRef = _db.collection('groups').doc(gid);
    batch.set(groupRef, _stamp({
      'name': group.name,
      'joinCode': group.joinCode,
      'ownerId': group.ownerId,
      'icon': group.icon,
      'tableSettings': tableSettingsToMap(group.tableSettings),
      'createdAt': FieldValue.serverTimestamp(),
    }));

    batch.set(groupRef.collection('members').doc(owner.id), {
      'name': owner.name,
      'role': 'admin',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    batch.set(
        userGroupIndexRef(owner.id, gid),
        GroupMembership(
                groupId: gid,
                name: group.name,
                icon: group.icon,
                pinned: false,
                role: 'admin')
            .toMap());

    // Store name + icon so joinByCode can populate the membership index
    // without reading groups/{gid} (which is member-only).
    batch.set(_db.collection('joinCodes').doc(group.joinCode.toUpperCase()),
        {'gid': gid, 'kind': 'group', 'name': group.name, 'icon': group.icon});

    await batch.commit();
  }

  /// Reads the raw `joinCodes/{code}` document without joining anything.
  /// Returns `{kind, gid, gameId?, name?, icon?}` or `null` when unknown.
  /// Used by the unified join screen to classify a code (group vs game/tv)
  /// before deciding which flow to run.
  Future<Map<String, dynamic>?> peekJoinCode(String code) async {
    final key = code.trim().toUpperCase();
    if (key.isEmpty) return null;
    final snap = await _db.collection('joinCodes').doc(key).get();
    if (!snap.exists) return null;
    return Map<String, dynamic>.from(snap.data()!);
  }

  /// Resolves a join code and joins atomically: reads joinCodes/{code}, writes
  /// members/{uid} + the user's index mirror. Returns the gid, or null when
  /// the code does not exist.
  Future<String?> joinByCode(String code, AppUser user) async {
    final key = code.trim().toUpperCase();
    final codeSnap = await _db.collection('joinCodes').doc(key).get();
    if (!codeSnap.exists) return null;
    final data = Map<String, dynamic>.from(codeSnap.data()!);
    final gid = data['gid'] as String?;
    if (gid == null) return null;
    // Read name/icon from the joinCodes doc (world-readable for signed-in users)
    // so we never have to touch groups/{gid} — non-members cannot read that doc.
    final name = (data['name'] as String?) ?? '';
    final icon = (data['icon'] as String?) ?? '♠️';
    return joinGroup(gid, user, groupName: name, groupIcon: icon);
  }

  /// Idempotent join: safe to call when already a member.
  /// [groupName] and [groupIcon] are used to populate the user's mirror index;
  /// they come from the joinCodes doc so this method never reads groups/{gid}.
  Future<String?> joinGroup(String gid, AppUser user,
      {String groupName = '', String groupIcon = '♠️'}) async {
    final batch = _db.batch();
    batch.set(
        _db.collection('groups').doc(gid).collection('members').doc(user.id),
        {
          'name': user.name,
          'role': 'member',
          'joinedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    batch.set(
        userGroupIndexRef(user.id, gid),
        GroupMembership(
                groupId: gid,
                name: groupName,
                icon: groupIcon,
                pinned: false,
                role: 'member')
            .toMap(),
        SetOptions(merge: true));
    await batch.commit();
    return gid;
  }

  Stream<List<GroupMembership>> groupsIndexStream(String uid) => _db
      .collection('users').doc(uid).collection('groups')
      .snapshots()
      .map((s) => s.docs.map((d) => GroupMembership.fromMap(d.id, d.data())).toList());

  /// Live member roster for a group (name/role only — the index-based group
  /// list on home/sidebar has no live member data, so we maintain it here to
  /// keep member counts real-time on the free plan).
  Stream<List<AppUser>> groupMembersStream(String gid) => _db
      .collection('groups').doc(gid).collection('members')
      .snapshots()
      .map((s) => [
            for (final d in s.docs)
              AppUser(
                id: d.id,
                name: (d.data()['name'] as String?) ?? '',
                email: '',
                isAdmin: (d.data()['role'] as String?) == 'admin',
                isCoAdmin: (d.data()['role'] as String?) == 'coadmin',
                stats: d.data()['stats'] is Map
                    ? userStatsFromMap(
                        Map<String, dynamic>.from(d.data()['stats'] as Map))
                    : const UserStats(
                        played: 0,
                        wins: 0,
                        podium: 0,
                        avgFinish: 0,
                        knockouts: 0),
              ),
          ]);

  Future<void> updateGroupIndex(String uid, String gid,
      {String? name, String? icon, bool? pinned, String? role}) =>
      userGroupIndexRef(uid, gid).set(
        {
          'name': ?name,
          'icon': ?icon,
          'pinned': ?pinned,
          'role': ?role,
        },
        SetOptions(merge: true),
      );

  Future<void> setMemberRole(String gid, String targetUid, String role) => _db
      .collection('groups').doc(gid).collection('members').doc(targetUid)
      .set({'role': role}, SetOptions(merge: true));

  Future<void> deleteMember(String gid, String targetUid) async {
    final batch = _db.batch();
    batch.delete(_db.collection('groups').doc(gid).collection('members').doc(targetUid));
    batch.delete(userGroupIndexRef(targetUid, gid));
    await batch.commit();
  }

  /// Persists the group's default table-capacity/randomization settings
  /// (owner/admin only — enforced by the caller, not by the client SDK).
  Future<void> updateGroupTableSettings(String gid, TableSettings settings) =>
      _db.collection('groups').doc(gid).update({
        'tableSettings': tableSettingsToMap(settings),
      });

  /// Looks up a registered user by exact (case-insensitive) email match, for
  /// the admin "add member directly" flow. Reads the public `emailIndex`
  /// (the `users` collection is private to each owner). Returns null when no
  /// account uses that email.
  Future<AppUser?> findUserByEmail(String email) async {
    final key = email.trim().toLowerCase();
    if (key.isEmpty) return null;
    final snap = await _db.collection('emailIndex').doc(key).get();
    final uid = snap.data()?['uid'] as String?;
    if (uid == null || uid.isEmpty) return null;
    return AppUser(
      id: uid,
      name: (snap.data()?['name'] as String?) ?? '',
      email: email.trim(),
      isAdmin: false,
      stats: const UserStats(
          played: 0, wins: 0, podium: 0, avgFinish: 0, knockouts: 0),
    );
  }

  /// Group admin adds a registered user directly. Writes the member row AND a
  /// `pendingInvites` doc (free plan — no Cloud Function, so `onMemberWrite`
  /// cannot mirror into the target user's /users tree; the added user instead
  /// reads their own pending invite on next open and self-writes their index).
  Future<void> addMemberToGroup(String gid, AppUser user,
      {String groupName = '', String groupIcon = '♠️'}) async {
    final batch = _db.batch();
    batch.set(
      _db.collection('groups').doc(gid).collection('members').doc(user.id),
      {
        'name': user.name,
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      _db.collection('pendingInvites').doc('$gid:${user.id}'),
      {
        'uid': user.id,
        'gid': gid,
        'name': groupName,
        'icon': groupIcon,
        'role': 'member',
        'createdAt': FieldValue.serverTimestamp(),
      },
    );
    await batch.commit();
  }

  /// Live stream of this user's pending group invites. Each invite carries the
  /// group id + name/icon so the client can self-write its own membership index
  /// without needing to read `groups/{gid}` (which is member-only).
  Stream<List<Map<String, dynamic>>> pendingInvitesStream(String uid) => _db
      .collection('pendingInvites')
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map((s) => [
            for (final d in s.docs) {...d.data(), '__inviteId': d.id},
          ]);

  /// Removes a pending invite once the user has accepted (self-mirrored) it.
  Future<void> removePendingInvite(String inviteId) => _db
      .collection('pendingInvites').doc(inviteId).delete();

  DocumentReference<Map<String, dynamic>> get serverTimeRef =>
      _db.collection('_meta').doc('serverTime');

  /// Full group assembly: meta doc + members + chat + polls + games merged
  /// into a single [Group]. Emits whenever any part changes. The first
  /// emission only happens once every source has delivered its initial
  /// snapshot.
  Stream<Group> groupBundleStream(String gid) {
    late StreamController<Group> controller;
    final subs = <StreamSubscription<dynamic>>[];

    Map<String, dynamic>? meta;
    var metaLoaded = false;
    List<AppUser> members = const [];
    var membersLoaded = false;
    List<ChatMessage> chat = const [];
    var chatLoaded = false;
    List<Poll> polls = const [];
    var pollsLoaded = false;
    List<LiveGame> games = const [];
    var gamesLoaded = false;

    void maybeEmit() {
      if (!(metaLoaded &&
          membersLoaded &&
          chatLoaded &&
          pollsLoaded &&
          gamesLoaded)) {
        return;
      }
      if (!controller.isClosed) {
        controller.add(Group(
          id: gid,
          name: (meta?['name'] as String?) ?? '',
          joinCode: (meta?['joinCode'] as String?) ?? '',
          ownerId: (meta?['ownerId'] as String?) ?? '',
          icon: (meta?['icon'] as String?) ?? '♠️',
          members: members,
          chat: chat,
          polls: polls,
          games: games,
          notifications: const [],
          tableSettings: meta?['tableSettings'] == null
              ? TableSettings.fallback
              : tableSettingsFromMap(
                  Map<String, dynamic>.from(meta!['tableSettings'] as Map)),
        ));
      }
    }

    final groupRef = _db.collection('groups').doc(gid);

    // A section that errors (e.g. a rule denies one subcollection, or a brief
    // permission-propagation gap right after joining) must not wedge the whole
    // bundle: mark it "loaded" with whatever data we have so [maybeEmit] can
    // still deliver the rest of the group and the UI leaves its loading state.
    void Function(Object, StackTrace) onSectionError(
      String section,
      void Function() markLoaded,
    ) =>
        (Object e, StackTrace _) {
          debugPrint('groupBundle "$section" error: $e');
          markLoaded();
          maybeEmit();
        };

    controller = StreamController<Group>(
      onListen: () {
        subs.add(groupRef.snapshots().listen((s) {
          meta = s.data();
          metaLoaded = true;
          maybeEmit();
        }, onError: onSectionError('meta', () => metaLoaded = true)));
        subs.add(groupRef.collection('members').snapshots().listen((s) {
          members = [
            for (final d in s.docs)
              AppUser(
                id: d.id,
                name: (d.data()['name'] as String?) ?? '',
                email: '',
                isAdmin: (d.data()['role'] as String?) == 'admin',
                isCoAdmin: (d.data()['role'] as String?) == 'coadmin',
                stats: d.data()['stats'] is Map
                    ? userStatsFromMap(
                        Map<String, dynamic>.from(d.data()['stats'] as Map))
                    : const UserStats(
                        played: 0,
                        wins: 0,
                        podium: 0,
                        avgFinish: 0,
                        knockouts: 0),
              ),
          ];
          membersLoaded = true;
          maybeEmit();
        }, onError: onSectionError('members', () => membersLoaded = true)));
        subs.add(groupRef.collection('chat').snapshots().listen((s) {
          chat = [for (final d in s.docs) chatMessageFromMap(d.data())];
          chatLoaded = true;
          maybeEmit();
        }, onError: onSectionError('chat', () => chatLoaded = true)));
        subs.add(groupRef.collection('polls').snapshots().listen((s) {
          polls = [for (final d in s.docs) pollFromMap(d.data())];
          pollsLoaded = true;
          maybeEmit();
        }, onError: onSectionError('polls', () => pollsLoaded = true)));
        subs.add(groupRef.collection('games').snapshots().listen((s) {
          games = [
            for (final d in s.docs)
              liveGameFromFirestoreDoc(Map<String, dynamic>.from(d.data())),
          ];
          gamesLoaded = true;
          maybeEmit();
        }, onError: onSectionError('games', () => gamesLoaded = true)));
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return controller.stream;
  }

  Future<void> sendGroupChatMessage(String gid, ChatMessage msg) => _db
      .collection('groups').doc(gid).collection('chat').doc(msg.id)
      .set(chatMessageToMap(msg));

  Future<void> markChatMessageDeleted(String gid, String msgId) => _db
      .collection('groups').doc(gid).collection('chat').doc(msgId)
      .set({'deleted': true}, SetOptions(merge: true));

  Future<void> savePoll(String gid, Poll poll) => _db
      .collection('groups').doc(gid).collection('polls').doc(poll.id)
      .set(pollToMap(poll));

  // ── Games ──────────────────────────────────────────────────────────────────
  Future<void> saveGame(LiveGame game) async {
    final fullDoc = liveGameToFirestoreDoc(game);
    
    // Save private sidecar so admin can recover on a new device
    final privateDoc = <String, dynamic>{
      'organizerPct': game.settings.organizerPct,
      if (game.structure != null) ...{
        'prizes': fullDoc['structure']['prizes'],
        'organizerAmount': fullDoc['structure']['organizerAmount'],
      }
    };
    await _db
        .collection('groups').doc(game.groupId)
        .collection('games').doc(game.id)
        .collection('admin').doc('privateData')
        .set(privateDoc, SetOptions(merge: true));

    // Scrub private fields from the public document
    final publicDoc = Map<String, dynamic>.from(fullDoc);
    
    final publicSettings = Map<String, dynamic>.from(publicDoc['settings'] as Map? ?? {});
    publicSettings.remove('organizerPct');
    publicDoc['settings'] = publicSettings;
    
    if (publicDoc['structure'] != null) {
      final publicStructure = Map<String, dynamic>.from(publicDoc['structure'] as Map);
      publicStructure.remove('prizes');
      publicStructure.remove('organizerAmount');
      publicDoc['structure'] = publicStructure;
    }
    
    await _db
        .collection('groups').doc(game.groupId)
        .collection('games').doc(game.id)
        .set(_stamp(publicDoc));
  }

  /// Saves the admin's undo history to a sidecar subcollection so it travels
  /// with the account across devices, without forcing players to download it.
  Future<void> saveUndoStack(String groupId, String gameId, List<LiveGame> stack) => _db
      .collection('groups').doc(groupId).collection('games').doc(gameId)
      .collection('admin').doc('undoStack')
      .set({
        'snapshots': stack.map(liveGameToFirestoreDoc).toList(),
      });

  /// Loads the admin's undo history sidecar document.
  Future<List<LiveGame>> loadUndoStack(String groupId, String gameId) async {
    final doc = await _db
        .collection('groups').doc(groupId).collection('games').doc(gameId)
        .collection('admin').doc('undoStack').get();
    if (!doc.exists) return [];
    
    final snapshots = doc.data()?['snapshots'] as List?;
    if (snapshots == null) return [];
    
    return snapshots
        .map((s) => liveGameFromFirestoreDoc(s as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>?> loadPrivateGameData(String groupId, String gameId) async {
    final snap = await _db
        .collection('groups').doc(groupId)
        .collection('games').doc(gameId)
        .collection('admin').doc('privateData')
        .get();
    return snap.data();
  }

  /// Targeted per-player / field patches using Firestore dot-paths — avoids
  /// clobbering unrelated concurrent edits (e.g. RSVPs while admin edits).
  Future<void> patchGame(
      String gid, String gameId, Map<String, dynamic> dotPaths) => _db
      .collection('groups').doc(gid).collection('games').doc(gameId)
      .set(_stamp(dotPaths), SetOptions(merge: true));

  /// Live game document. Both admins and members follow the raw doc — members
  /// are gated to `isMember(gid)` by rules and the app sanitizes payout /
  /// organizer figures for non-authority viewers before display. (The old
  /// per-member `memberViews` projection needed a Cloud Function to maintain
  /// it; this build runs without functions.)
  Stream<DocumentSnapshot<Map<String, dynamic>>> gameDocSnapshots(
          String gid, String gameId, {bool isAdmin = false}) =>
      _db
          .collection('groups')
          .doc(gid)
          .collection('games')
          .doc(gameId)
          .snapshots();

  /// Registers the game's public/tv codes for lookup flows.
  Future<void> upsertGameCodes(LiveGame game) async {
    final batch = _db.batch();
    batch.set(_db.collection('joinCodes').doc(game.publicCode.toUpperCase()),
        {'gid': game.groupId, 'gameId': game.id, 'kind': 'game'});
    batch.set(_db.collection('joinCodes').doc(game.tvCode.toUpperCase()),
        {'gid': game.groupId, 'gameId': game.id, 'kind': 'tv'});
    await batch.commit();
  }

  /// Writes sanitized projection payloads readable by non-members
  /// (TV mode browsers, guests) under publicGames/{gameId}.
  Future<void> publishPublicProjections({
    required LiveGame game,
    required Map<String, dynamic> tv,
    required Map<String, dynamic> player,
    required Map<String, dynamic> guest,
  }) =>
      _db.collection('publicGames').doc(game.id).set(_stamp({
        'gid': game.groupId,
        'publicCode': game.publicCode,
        'tvCode': game.tvCode,
        'status': game.status.name,
        'tv': tv,
        'player': player,
        'guest': guest,
      }));

  Stream<Map<String, dynamic>> publicGameStream(String gameId) => _db
      .collection('publicGames').doc(gameId)
      .snapshots()
      .map((s) => s.data() ?? const {});

  /// Resolves a public/tv code to `(gid, gameId, kind)` or null.
  Future<({String gid, String gameId, String kind})?> findGameByCode(
      String code) async {
    final key = code.trim().toUpperCase();
    final snap = await _db.collection('joinCodes').doc(key).get();
    if (!snap.exists) return null;
    final data = Map<String, dynamic>.from(snap.data()!);
    final gameId = data['gameId'] as String?;
    final gid = data['gid'] as String?;
    if (gid == null || gameId == null) return null;
    return (
      gid: gid,
      gameId: gameId,
      kind: (data['kind'] as String?) ?? 'game',
    );
  }

  // ── Request queue (guest/member → admin) ───────────────────────────────────
  CollectionReference<Map<String, dynamic>> _requestsCol(String gameId) =>
      _db.collection('requests').doc(gameId).collection('items');

  /// Queues a request for the admin device. When [idempotencyKey] is given
  /// the write targets a deterministic doc id, so a double-tap / retry
  /// overwrites the same request instead of enqueueing a duplicate (spec
  /// §18.1 idempotency keys).
  Future<void> pushRequest({
    required String gameId,
    required String kind,
    required Map<String, dynamic> payload,
    String? idempotencyKey,
  }) {
    final data = <String, dynamic>{
      'kind': kind,
      ...payload,
      'consumed': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
    final key = idempotencyKey?.trim();
    if (key == null || key.isEmpty) return _requestsCol(gameId).add(data);
    return _requestsCol(gameId).doc(key).set(data);
  }

  /// Atomically reserves guest slot ([inviterId], [slot]) for [gameId] by
  /// creating the deterministic claim doc `guestCheckIn-$inviterId-$slot`
  /// inside a transaction (user-flow spec §7.1 "duplicate slot claims are
  /// blocked server-side", tech spec §21 "first reservation wins"). Racing
  /// guests are serialized by Firestore: the loser's retry re-reads the doc,
  /// sees it held and gets an error instead of enqueueing a second request.
  /// Returns null on success, or a user-facing error string.
  Future<String?> reserveGuestSlotTx({
    required String gameId,
    required String inviterId,
    required int slot,
    required Map<String, dynamic> payload,
  }) {
    final ref = _requestsCol(gameId).doc('guestCheckIn-$inviterId-$slot');
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      // M5 fix: ANY existing claim (consumed or pending) means the slot is
      // already taken. The previous logic only blocked when
      // `consumed != true`, so a CONFIRMED (consumed=true) slot could be
      // re-claimed by another guest. A consumed claim = permanently taken; a
      // pending claim = locked while awaiting admin confirmation. Only a
      // nonexistent doc (slot freed via releaseSlotClaim) is claimable.
      if (snap.exists) {
        return 'That guest slot is already claimed.';
      }
      tx.set(ref, {
        'kind': 'guestCheckIn',
        ...payload,
        'consumed': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    });
  }

  /// Deletes a slot-claim lock so the slot becomes claimable again (admin
  /// rejected the guest or freed the seat — user-flow spec §7.1).
  Future<void> releaseSlotClaim(String gameId, String inviterId, int slot) =>
      _requestsCol(gameId).doc('guestCheckIn-$inviterId-$slot').delete();

  Stream<List<GameRequest>> requestsStream(String gameId) => _requestsCol(gameId)
      .where('consumed', isEqualTo: false)
      .snapshots()
      .map((s) => [
            for (final d in s.docs)
              GameRequest(
                id: d.id,
                kind: (d.data()['kind'] as String?) ?? '',
                payload: Map<String, dynamic>.from(d.data()),
                createdAt:
                    (d.data()['createdAt'] as Timestamp?)?.toDate() ??
                        DateTime.now(),
              ),
          ]);

  Future<void> consumeRequest(String gameId, String requestId) =>
      _requestsCol(gameId)
          .doc(requestId)
          .set({'consumed': true}, SetOptions(merge: true));

  // ── Cash sessions ──────────────────────────────────────────────────────────
  Future<void> saveCashSession(String gid, CashSession session) => _db
      .collection('groups').doc(gid).collection('cashSessions').doc(session.id)
      .set(_stamp(cashSessionToMap(session)));

  Stream<List<CashSession>> completedCashSessionsStream(String gid) => _db
      .collection('groups').doc(gid).collection('cashSessions')
      .where('isCompleted', isEqualTo: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) cashSessionFromMap(d.data())]);

  // ── Presets / chip sets ────────────────────────────────────────────────────
  Future<void> savePreset(String uid, TournamentPreset preset) => _db
      .collection('users').doc(uid).collection('presets').doc(preset.id)
      .set(tournamentPresetToMap(preset));

  Future<void> deletePreset(String uid, String presetId) => _db
      .collection('users').doc(uid).collection('presets').doc(presetId).delete();

  Stream<List<TournamentPreset>> presetsStream(String uid) => _db
      .collection('users').doc(uid).collection('presets')
      .snapshots()
      .map((s) => [for (final d in s.docs) tournamentPresetFromMap(d.data())]);

  Future<void> saveChipSet(
          String uid, String id, String name, List<ChipColor> chips) =>
      _db.collection('users').doc(uid).collection('chipSets').doc(id).set({
        'name': name,
        'chips': chips.map(chipColorToMap).toList(),
      });

  Future<void> deleteChipSet(String uid, String id) => _db
      .collection('users').doc(uid).collection('chipSets').doc(id).delete();

  Stream<List<({String id, String name, List<ChipColor> chips})>>
      chipSetsStream(String uid) => _db
          .collection('users').doc(uid).collection('chipSets')
          .snapshots()
          .map((s) => [
                for (final d in s.docs)
                  (
                    id: d.id,
                    name: (d.data()['name'] as String?) ?? '',
                    chips: (d.data()['chips'] as List? ?? const [])
                        .map((e) => chipColorFromMap(Map<String, dynamic>.from(e as Map)))
                        .toList(),
                  ),
              ]);

  // ── Notification fan-out ───────────────────────────────────────────────────
  // FREE-PLAN fan-out (no Cloud Function, no Blaze plan):
  //  1. The originating device stages ONE notification in the group outbox.
  //  2. Every member device mirrors outbox items it hasn't seen into ITS OWN
  //     inbox — rules only allow the inbox owner to create docs.
  //  3. The originating device also fans the event out as a REAL push
  //     (OneSignal REST API, include_aliases = member uids).
  Future<void> stageGroupNotification(
      String gid, AppNotification notification) =>
      _db
          .collection('groups').doc(gid).collection('notifications')
          .doc(notification.id)
          .set(_stamp({
            'title': notification.title,
            'body': notification.body,
            'type': notification.type.name,
            'link': notification.link,
            'read': false,
            'timestamp': FieldValue.serverTimestamp(),
            if (notification.audience != null &&
                notification.audience!.isNotEmpty)
              'audience': notification.audience,
          }));

  /// Live stream of a group's staged-notification outbox.
  Stream<List<OutboxNotification>> groupOutboxStream(String gid) => _db
      .collection('groups').doc(gid).collection('notifications')
      .snapshots()
      .map((s) => [
            for (final d in s.docs)
              OutboxNotification(
                id: d.id,
                title: (d.data()['title'] as String?) ?? '',
                body: (d.data()['body'] as String?) ?? '',
                type: notificationTypeByName(d.data()['type']),
                link: d.data()['link'] as String?,
                audience: (d.data()['audience'] as List?)
                    ?.map((e) => e.toString())
                    .toList(),
                timestamp: (d.data()['timestamp'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
                updatedAtMillis: (d.data()['updatedAt'] as Timestamp?)
                        ?.millisecondsSinceEpoch ??
                    0,
              ),
          ]);

  /// Mirrors a staged outbox notification into the signed-in user's OWN inbox.
  Future<void> mirrorInboxNotification(
    String uid,
    AppNotification notification, {
    bool read = false,
  }) =>
      _db.collection('users').doc(uid).collection('notifications')
          .doc(notification.id)
          .set({
            'id': notification.id,
            'title': notification.title,
            'body': notification.body,
            'type': notification.type.name,
            'link': notification.link,
            'read': read,
            'timestamp': notification.timestamp.toIso8601String(),
          });

  Stream<List<AppNotification>> notificationsStream(String uid) => _db
      .collection('users').doc(uid).collection('notifications')
      .orderBy('timestamp', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => [for (final d in s.docs) appNotificationFromMap(d.data())]);

  Future<void> markNotificationRead(String uid, String notificationId) => _db
      .collection('users').doc(uid).collection('notifications').doc(notificationId)
      .set({'read': true}, SetOptions(merge: true));

  Future<void> markAllNotificationsRead(String uid) async {
    final docs =
        await _db.collection('users').doc(uid).collection('notifications').get();
    final unread = docs.docs.where((d) => d.data()['read'] == false);
    final batch = _db.batch();
    for (final d in unread) {
      batch.set(d.reference, {'read': true}, SetOptions(merge: true));
    }
    await batch.commit();
  }
}

/// Debug logger used by repository callers to trace sync behaviour.
@visibleForTesting
void logRepo(Object message) => debugPrint('[FirebaseRepository] $message');
