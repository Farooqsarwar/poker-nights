import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';
import 'package:localstore/localstore.dart' show Localstore;

import '../models/app_notification.dart';
import '../models/cash_game.dart';
import '../models/chat_report.dart';
import '../models/chip_color.dart';
import '../models/game.dart';
import '../models/group.dart';
import '../models/imported_night.dart';
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
        icon: (m['icon'] as String?) ?? '♠',
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
    this.eliminatedAtLevel,
  });

  final String gameId;
  final String groupId;

  /// 1-based finishing position.
  final int position;
  final int playerCount;
  final int knockouts;
  final DateTime? finishedAt;
  final int? eliminatedAtLevel;

  Map<String, dynamic> toMap() => {
    'gameId': gameId,
    'groupId': groupId,
    'position': position,
    'playerCount': playerCount,
    'knockouts': knockouts,
    'finishedAt': finishedAt,
    'eliminatedAtLevel': eliminatedAtLevel,
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
        eliminatedAtLevel: (m['eliminatedAtLevel'] as num?)?.toInt(),
      );
}

/// A document that lives OUTSIDE `groups/{gid}`, named without a Firestore
/// handle so the set of them a delete must remove can be asserted in a unit
/// test. Both fields are an existing Firestore path segment: [collection] is a
/// top-level collection name and [id] is a non-empty document id.
typedef ExternalRef = ({String collection, String id});

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
  /// Document key for the email -> uid index.
  ///
  /// The address is HASHED, so `emailIndex` no longer stores plaintext and a
  /// caller must already know the exact address to look one up. Keyed by the
  /// address itself, the collection was an account-existence oracle: any
  /// signed-in caller, anonymous guests included, could confirm whether an
  /// address had an account and read its uid (19-005, 19-023).
  static String emailIndexKey(String email) =>
      sha256.convert(utf8.encode(email.trim().toLowerCase())).toString();

  /// Persisted via [initDeviceId] so it survives app restarts — echo
  /// prevention and the single-active-editor claim key off this, and a fresh
  /// id on every launch defeated the editor-staleness window.
  String? _deviceId;
  String get deviceId => _deviceId ??= _freshDeviceId();

  /// Identity of THIS TAB, for the current run only. Never persisted.
  ///
  /// [deviceId] lives in Localstore, which is per-ORIGIN and therefore shared
  /// by every tab of the app in the same browser. Stamping writes with it
  /// meant two tabs looked identical to each other, so the echo guard in
  /// `_adoptRemoteMap` discarded the other tab's writes as its own: open TV
  /// Mode in a second tab while signed in as host and that TV froze, quietly,
  /// for the rest of the night.
  ///
  /// Writes are stamped with this instead, so two tabs stay in step. The
  /// editor claim deliberately keeps using [deviceId] — it wants continuity
  /// across a reload, which a per-run id would throw away.
  late final String sessionId = '${deviceId}_${_freshDeviceId()}';

  static String _freshDeviceId() {
    final r = Random();
    // Build the suffix from 4-bit chunks — `1 << 32` overflows to 0 on web,
    // which made `Random().nextInt(1 << 32)` throw a RangeError.
    final suffix = List.generate(
      8,
      (_) => r.nextInt(16).toRadixString(16),
    ).join();
    return 'dev-${DateTime.now().millisecondsSinceEpoch}-$suffix';
  }

  /// Loads the persisted device id (or creates + stores one on first run).
  /// Call once during startup, before any write.
  Future<void> initDeviceId() async {
    if (_deviceId != null) return;
    try {
      final doc = await Localstore.instance
          .collection('app')
          .doc('device')
          .get();
      final saved = doc?['deviceId'] as String?;
      if (saved != null && saved.isNotEmpty) {
        _deviceId = saved;
        return;
      }
    } catch (_) {
      // Localstore unavailable (tests) — fall through to an in-memory id.
    }
    final fresh = _freshDeviceId();
    _deviceId = fresh;
    try {
      await Localstore.instance.collection('app').doc('device').set({
        'deviceId': fresh,
      });
    } catch (_) {
      // Best-effort persistence; the in-memory id still works for this run.
    }
  }

  Map<String, dynamic> _stamp(Map<String, dynamic>? data) => {
    ...?data,
    'updatedAt': FieldValue.serverTimestamp(),
    // Per-TAB, not per-device — see [sessionId].
    'writerId': sessionId,
  };

  // ── Auth ───────────────────────────────────────────────────────────────────
  Stream<fa.User?> authStateChanges() => _auth.authStateChanges();

  /// Guarded like the constructor's own `authStateChanges()` subscription:
  /// widget tests mount screens before `Firebase.initializeApp()` runs, and
  /// `FirebaseAuth.instance` throws `[core/no-app]` the instant it is
  /// touched — not just when a network call is made. Unlike that
  /// subscription, this getter has call sites reachable straight from
  /// `build()` (`AppProvider.isGuest`), so without a guard of its own the
  /// same "Firebase unavailable" case that the constructor already tolerates
  /// crashes on the first read here. Falls back to "no user", the same
  /// answer as a fresh, unauthenticated session.
  fa.User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  String? get currentUid => currentUser?.uid;

  /// The signed-in user's Premium entitlement, as held on the server.
  ///
  /// `entitlements/{uid}` is READ-ONLY to every client (`allow write: if
  /// false` in firestore.rules), so this value cannot be forged from the app
  /// however the device is tampered with. It is granted out of band — the
  /// Firebase console, or the Admin SDK from a machine the owner controls.
  ///
  /// Returns false when absent, unreadable or offline: the safe answer to
  /// "has this person paid?" is no.
  Future<bool> fetchPremiumEntitlement() async {
    final uid = currentUid;
    if (uid == null) return false;
    try {
      final doc = await _db.collection('entitlements').doc(uid).get();
      return (doc.data()?['premium'] as bool?) ?? false;
    } catch (e) {
      debugPrint('fetchPremiumEntitlement failed: $e');
      return false;
    }
  }
  bool get isSignedInAsGuest => currentUser?.isAnonymous ?? false;

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

  // Web OAuth 2.0 client ID (type 3 in google-services.json / GoogleService-Info.plist).
  // Used on Android & iOS as the serverClientId so Firebase receives a valid
  // ID-token audience.  On web the popup flow uses the same ID.
  // clientSecret is only required for the desktop PKCE flow — leave it null
  // on mobile so the package uses the native Google Sign-In SDK instead.
  static const _webClientId =
      '885018943861-j9abh2tqc4eiqr58bc9ihel3l2d3q89f.apps.googleusercontent.com';

  static final GoogleSignIn googleSignIn = GoogleSignIn(
    params: const GoogleSignInParams(
      clientId: _webClientId,
      scopes: ['openid', 'profile', 'email'],
    ),
  );

  /// Initialises the [GoogleSignIn] singleton.
  /// The package handles initialization automatically — no pre-warming needed.
  static Future<void> initGoogleSignIn() async {
    // Intentionally empty: calling silentSignIn() here would cache a session
    // and cause signIn() to skip the account chooser on the next explicit
    // sign-in attempt. The package self-initializes on first use.
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
  /// `null` when the user cancels the flow. Throws on real errors so the
  /// caller can surface a meaningful message.
  Future<fa.UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      return await _auth.signInWithPopup(
        fa.GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'}),
      );
    }
    // Clear any stored token first so there's no leftover session.
    try {
      await googleSignIn.signOut();
    } catch (_) {}
    // signInOnline() always triggers the full OAuth web flow, bypassing the
    // "use previously selected account" shortcut that signIn() uses.
    final credentials = await googleSignIn.signInOnline();
    if (credentials == null) return null;
    final credential = await _googleCredential(credentials);
    return _auth.signInWithCredential(credential);
  }

  /// Signs in to Firebase with existing credentials.
  Future<fa.UserCredential?> signInWithGoogleCredentials(
    GoogleSignInCredentials credentials,
  ) async {
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
    if (kIsWeb) {
      return await user.linkWithPopup(
        fa.GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'}),
      );
    }
    try {
      await googleSignIn.signOut();
    } catch (_) {}
    final credentials = await googleSignIn.signInOnline();
    if (credentials == null) return null;
    final credential = await _googleCredential(credentials);
    return user.linkWithCredential(credential);
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
  /// The provider ids backing the signed-in account, e.g. `password`,
  /// `google.com`. Empty for an anonymous guest.
  Set<String> get signInProviders =>
      _auth.currentUser?.providerData.map((p) => p.providerId).toSet() ??
      const {};

  /// True when deleting requires the user to retype their password. Google and
  /// guest accounts re-authenticate without one.
  bool get deleteNeedsPassword =>
      signInProviders.contains('password') &&
      !signInProviders.contains('google.com');

  /// Re-establishes a "recent login". Firebase rejects [deleteAccount] with
  /// `requires-recent-login` when the credential is more than a few minutes
  /// old, which is the normal case for anyone who did not just sign in.
  Future<void> reauthenticate({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final providers = signInProviders;

    if (providers.contains('google.com')) {
      if (kIsWeb) {
        await user.reauthenticateWithPopup(
          fa.GoogleAuthProvider()
            ..setCustomParameters({'prompt': 'select_account'}),
        );
        return;
      }
      final credentials = await googleSignIn.signInOnline();
      if (credentials == null) {
        throw fa.FirebaseAuthException(
          code: 'user-cancelled',
          message: 'Re-authentication was cancelled.',
        );
      }
      await user.reauthenticateWithCredential(
        await _googleCredential(credentials),
      );
      return;
    }

    if (providers.contains('password')) {
      final email = user.email;
      if (email == null || password == null || password.isEmpty) {
        throw fa.FirebaseAuthException(
          code: 'missing-password',
          message: 'Please enter your password to confirm.',
        );
      }
      await user.reauthenticateWithCredential(
        fa.EmailAuthProvider.credential(email: email, password: password),
      );
      return;
    }
    // Anonymous guest: there is no credential to re-present, and Firebase
    // allows an anonymous user to delete itself without one.
  }

  Future<void> deleteAccount({String? password}) async {
    final uid = currentUid;
    if (uid == null) return;
    final email = _auth.currentUser?.email;

    // BEFORE anything is destroyed. The auth user can only be removed after
    // the Firestore cleanup (every rule keys off `request.auth.uid`), so a
    // `requires-recent-login` discovered at that point would leave the profile
    // deleted and the credential alive. Proving freshness up front means a
    // failed re-auth costs nothing -- no data has been touched yet.
    await reauthenticate(password: password);
    final userDoc = _db.collection('users').doc(uid);

    final memberships = await userDoc.collection('groups').get();
    final batch = _db.batch();
    for (final m in memberships.docs) {
      batch.delete(m.reference);
      batch.delete(
        _db.collection('groups').doc(m.id).collection('members').doc(uid),
      );
    }
    // `results` belongs here: it is the player's private per-game finish
    // mirror. Left behind it is unreadable by anyone — the read rule keys off
    // a uid that no longer exists — but still stored, which is exactly the
    // residue account deletion is supposed to remove.
    for (final sub in const [
      'presets',
      'chipSets',
      'notifications',
      'results',
      'soloGames',
    ]) {
      final docs = await userDoc.collection(sub).get();
      for (final d in docs.docs) {
        batch.delete(d.reference);
      }
    }
    // The public email -> uid row written by [ensureUserDoc]. Without this the
    // address stayed resolvable after deletion and `findUserByEmail` kept
    // handing admins a uid with no account behind it.
    if (email != null && email.trim().isNotEmpty) {
      batch.delete(_db.collection('emailIndex').doc(emailIndexKey(email)));
    }
    batch.delete(userDoc);
    // Firestore first, auth last: the order is forced because every rule above
    // keys off `request.auth.uid`, so removing the auth user first would strip
    // the permission needed to clean up. The re-auth above is what makes this
    // order safe.
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
      batch.set(
        ref,
        _stamp({
          'name': name,
          'email': email,
          'emailLower': emailLower,
          'stats': userStatsToMap(
            const UserStats(
              played: 0,
              wins: 0,
              podium: 0,
              avgFinish: 0,
              knockouts: 0,
            ),
          ),
          'prefs': <String, dynamic>{},
          'createdAt': FieldValue.serverTimestamp(),
        }),
      );
      if (emailLower.isNotEmpty) {
        // Public email→uid index for the admin "add member by email" flow.
        batch.set(_db.collection('emailIndex').doc(emailIndexKey(emailLower)), {
          'uid': uid,
          'name': name,
        });
      }
      for (final p in starterPresets) {
        batch.set(
          ref.collection('presets').doc(p.id),
          tournamentPresetToMap(p),
        );
      }
      if (starterChipSet != null) {
        batch.set(ref.collection('chipSets').doc(starterChipSet.id), {
          'name': starterChipSet.name,
          'chips': [for (final c in starterChipSet.chips) chipColorToMap(c)],
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
      if ((data['emailLower'] as String?) != emailLower &&
          emailLower.isNotEmpty) {
        await ref.set(
          _stamp({'email': email, 'emailLower': emailLower}),
          SetOptions(merge: true),
        );
      }
      if (emailLower.isNotEmpty) {
        await _db
            .collection('emailIndex')
            .doc(emailIndexKey(emailLower))
            .set({'uid': uid, 'name': storedName}, SetOptions(merge: true));
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
              played: 0,
              wins: 0,
              podium: 0,
              avgFinish: 0,
              knockouts: 0,
            )
          : userStatsFromMap(Map<String, dynamic>.from(data['stats'] as Map)),
    );
  }

  Future<void> updateUserProfile(String uid, {String? name, String? email}) =>
      _db
          .collection('users')
          .doc(uid)
          .set(
            _stamp({
              'name': ?name,
              'email': ?email,
              if (email != null) 'emailLower': email.trim().toLowerCase(),
            }),
            SetOptions(merge: true),
          );

  Future<void> saveUserPref(String uid, String key, Object? value) => _db
      .collection('users')
      .doc(uid)
      .set(
        _stamp({
          'prefs': {key: value},
        }),
        SetOptions(merge: true),
      );

  /// Reads the stored per-user preferences map (`users/{uid}.prefs`).
  Future<Map<String, dynamic>> loadUserPrefs(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    if (!snap.exists) return const {};
    final prefs = snap.data()!['prefs'];
    return prefs is Map ? Map<String, dynamic>.from(prefs) : const {};
  }

  /// Persists the signed-in player's own result for a settled tournament.
  /// Doc id is the gameId so re-writes are idempotent.
  Future<void> saveGameResult(String uid, String gameId, GameResultRow row) =>
      _db
          .collection('users')
          .doc(uid)
          .collection('results')
          .doc(gameId)
          .set(
            _stamp({
              ...row.toMap(),
              'finishedAt': FieldValue.serverTimestamp(),
            }),
          );

  /// Live stream of every result this player has recorded — the source of
  /// truth for lifetime stats.
  Stream<List<GameResultRow>> resultsStream(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('results')
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            GameResultRow.fromMap(d.id, Map<String, dynamic>.from(d.data())),
        ],
      );

  /// Mirrors a compact stats summary onto the caller's own roster row
  /// (`groups/{gid}/members/{uid}`) so other members' devices can display it
  /// without reading private profile data.
  Future<void> saveMemberStats(String gid, String uid, UserStats stats) => _db
      .collection('groups')
      .doc(gid)
      .collection('members')
      .doc(uid)
      .set({'stats': userStatsToMap(stats)}, SetOptions(merge: true));

  // ── Groups ─────────────────────────────────────────────────────────────────
  DocumentReference userGroupIndexRef(String uid, String gid) =>
      _db.collection('users').doc(uid).collection('groups').doc(gid);

  /// Creates the group doc, owner membership row, the owner's mirror index
  /// entry and the join-code lookup entry in one atomic batch.
  Future<void> createGroup(Group group, AppUser owner) async {
    final gid = group.id;
    final batch = _db.batch();

    final groupRef = _db.collection('groups').doc(gid);
    batch.set(
      groupRef,
      _stamp({
        'name': group.name,
        'joinCode': group.joinCode,
        'ownerId': group.ownerId,
        'icon': group.icon,
        'tableSettings': tableSettingsToMap(group.tableSettings),
        'createdAt': FieldValue.serverTimestamp(),
      }),
    );

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
        role: 'admin',
      ).toMap(),
    );

    // Store name + icon so joinByCode can populate the membership index
    // without reading groups/{gid} (which is member-only).
    batch.set(_db.collection('joinCodes').doc(group.joinCode.toUpperCase()), {
      'gid': gid,
      'kind': 'group',
      'name': group.name,
      'icon': group.icon,
      // Shown on the invite preview before anyone joins (E6). Kept fresh by
      // the host's device, see [updateInvitePreview].
      'hostName': owner.name,
      'memberCount': 1,
      'gamesPlayed': 0,
    });

    await batch.commit();
  }

  /// Refreshes the public numbers on a group's `joinCodes` doc so the invite
  /// preview shows the group as it is now. Host-only by rule (there is no
  /// Cloud Function to do it); never carries anything a code holder cannot
  /// already see on the join screen.
  Future<void> updateInvitePreview(
    String code, {
    required String name,
    required String icon,
    required String hostName,
    required int memberCount,
    required int gamesPlayed,
  }) => _db.collection('joinCodes').doc(code.trim().toUpperCase()).update({
    'name': name,
    'icon': icon,
    'hostName': hostName,
    'memberCount': memberCount,
    'gamesPlayed': gamesPlayed,
  });

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
    final icon = (data['icon'] as String?) ?? '♠';
    // The code travels onto the membership row so the RULES can verify it
    // against `groups/{gid}.joinCode`. Checking it only here (client-side) let
    // any signed-in user — including an anonymous guest — join any group by id
    // without ever holding the code (19-003, User Flow section 2.3).
    return joinGroup(gid, user, groupName: name, groupIcon: icon, joinCode: key);
  }

  /// Idempotent join: safe to call when already a member.
  /// [groupName] and [groupIcon] are used to populate the user's mirror index;
  /// they come from the joinCodes doc so this method never reads groups/{gid}.
  Future<String?> joinGroup(
    String gid,
    AppUser user, {
    String groupName = '',
    String groupIcon = '??',
    String joinCode = '',
  }) async {
    final memberRef = _db
        .collection('groups')
        .doc(gid)
        .collection('members')
        .doc(user.id);
    final snap = await memberRef.get();

    final batch = _db.batch();
    if (snap.exists) {
      batch.set(memberRef, {'name': user.name}, SetOptions(merge: true));
    } else {
      batch.set(memberRef, {
        'name': user.name,
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
        // Proof of code possession, verified by the rules against
        // `groups/{gid}.joinCode` on create.
        'viaCode': joinCode.trim().toUpperCase(),
      });
    }
    batch.set(
      userGroupIndexRef(user.id, gid),
      GroupMembership(
        groupId: gid,
        name: groupName,
        icon: groupIcon,
        pinned: false,
        role: 'member',
      ).toMap(),
      SetOptions(merge: true),
    );
    await batch.commit();
    return gid;
  }

  Stream<List<GroupMembership>> groupsIndexStream(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('groups')
      .snapshots()
      .map(
        (s) =>
            s.docs.map((d) => GroupMembership.fromMap(d.id, d.data())).toList(),
      );

  /// Live member roster for a group (name/role only — the index-based group
  /// list on home/sidebar has no live member data, so we maintain it here to
  /// keep member counts real-time on the free plan).
  Stream<List<AppUser>> groupMembersStream(String gid) => _db
      .collection('groups')
      .doc(gid)
      .collection('members')
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            AppUser(
              id: d.id,
              name: (d.data()['name'] as String?) ?? '',
              email: '',
              isAdmin: (d.data()['role'] as String?) == 'admin',
              isCoAdmin: (d.data()['role'] as String?) == 'coadmin',
              stats: d.data()['stats'] is Map
                  ? userStatsFromMap(
                      Map<String, dynamic>.from(d.data()['stats'] as Map),
                    )
                  : const UserStats(
                      played: 0,
                      wins: 0,
                      podium: 0,
                      avgFinish: 0,
                      knockouts: 0,
                    ),
            ),
        ],
      );

  Future<void> updateGroupIndex(
    String uid,
    String gid, {
    String? name,
    String? icon,
    bool? pinned,
    String? role,
  }) => userGroupIndexRef(uid, gid).set({
    'name': ?name,
    'icon': ?icon,
    'pinned': ?pinned,
    'role': ?role,
  }, SetOptions(merge: true));

  Future<void> setMemberRole(String gid, String targetUid, String role) => _db
      .collection('groups')
      .doc(gid)
      .collection('members')
      .doc(targetUid)
      .set({'role': role}, SetOptions(merge: true));

  Future<void> deleteMember(String gid, String targetUid) async {
    final batch = _db.batch();
    batch.delete(
      _db.collection('groups').doc(gid).collection('members').doc(targetUid),
    );
    batch.delete(userGroupIndexRef(targetUid, gid));
    await batch.commit();
  }

  /// Persists the group's default table-capacity/randomization settings
  /// (owner/admin only — enforced by the caller, not by the client SDK).
  Future<void> updateGroupTableSettings(String gid, TableSettings settings) =>
      _db.collection('groups').doc(gid).update({
        'tableSettings': tableSettingsToMap(settings),
      });

  /// B10: points the group at one of the owner's saved chip sets.
  ///
  /// Passing null clears the pointer, which is what the Standard box on the
  /// chips screen means by "no saved set". The field is deleted rather than
  /// written as null so the stored document matches what `groupToMap` produces
  /// for a null pointer -- the codec omits the key entirely, and a stored null
  /// would come back as a key that never matches that shape.
  Future<void> updateGroupDefaultChipSet(String gid, String? id) => _db
      .collection('groups')
      .doc(gid)
      .update({
        'defaultChipSetId': id ?? FieldValue.delete(),
      });

  /// B9: retires [oldCode] and issues [newCode] for the same group in one
  /// commit.
  ///
  /// "Re-roll the code - the old code and link stop working at once" (§B9,
  /// §3143). That "at once" is the whole requirement, and it is why this is a
  /// transaction rather than two writes: the group document has to start
  /// handing out the new code in the same commit that deletes the old
  /// `joinCodes` row, or there is a window where the old invite link still
  /// resolves a group whose own document disagrees with it.
  ///
  /// Returns false when [newCode] is already taken, so the caller can draw
  /// another. The rules would refuse such a write anyway -- `joinCodes` allows
  /// `create` but not `update` -- so this is checked to report a retry rather
  /// than an error, and the read is inside the transaction so two hosts
  /// re-rolling at the same moment cannot both win.
  Future<bool> rerollGroupJoinCode({
    required String gid,
    required String oldCode,
    required String newCode,
    required String name,
    required String icon,
    required String hostName,
    required int memberCount,
    required int gamesPlayed,
  }) =>
      _db.runTransaction<bool>((txn) async {
        final codes = _db.collection('joinCodes');
        final next = newCode.toUpperCase();
        final previous = oldCode.toUpperCase();
        // Every read first: a transaction may not read after it has written.
        final clash = await txn.get(codes.doc(next));
        if (clash.exists) return false;

        txn.update(_db.collection('groups').doc(gid), {'joinCode': next});
        txn.set(codes.doc(next), {
          'gid': gid,
          'kind': 'group',
          'name': name,
          'icon': icon,
          'hostName': hostName,
          'memberCount': memberCount,
          'gamesPlayed': gamesPlayed,
        });
        if (previous != next) txn.delete(codes.doc(previous));
        return true;
      });

  /// The rows one game leaves behind OUTSIDE `groups/{gid}` — the only two kinds
  /// a recursive group delete cannot reach by walking the group document.
  ///
  ///  * `publicGames/{gameId}` — the sanitized projection, written by
  ///    `publishPublicProjections` and readable under `allow read: if true`,
  ///    which is to say by anyone at all, with no group context. Delete the game
  ///    document without it and the row still answers a GET with the group's
  ///    gid, the event name, the date, the time and the chip structure: an
  ///    orphan that is both unresolvable and still readable. E7 (spec line
  ///    3143) gives the projection the lifetime of the game, and a group delete
  ///    has to honour that for every game the group ever ran, not just the live
  ///    one.
  ///  * `joinCodes/{publicCode}` and `joinCodes/{tvCode}` — the lookup rows
  ///    `upsertGameCodes` writes, under `allow get: if true` because an invite
  ///    link and a TV QR must resolve before sign-in. A dead code keeps
  ///    resolving to a gid and a gameId whose game no longer exists.
  ///
  /// A blank code yields no ref at all rather than an empty document id:
  /// `collection('')` addresses the collection, not a document.
  ///
  /// A MISSING code must be just as unremarkable as a blank one. E7 releases a
  /// game's projection and both its codes once the game is completed or
  /// cancelled — that release is not built yet, so today these rows are simply
  /// never removed, but the moment it is, a group with a finished night in its
  /// history hands this function absent codes. Naming a ref that is not there is
  /// not harmless (see [_existingRefs]), so "no such document" and "no such
  /// code" both have to resolve to no ref.
  ///
  /// Pure, so the reference set can be pinned by a test without a Firestore.
  @visibleForTesting
  static List<ExternalRef> externalGameRefs({
    required String gameId,
    String? publicCode,
    String? tvCode,
  }) {
    final refs = <ExternalRef>[];
    final id = gameId.trim();
    if (id.isNotEmpty) {
      refs.add((collection: 'publicGames', id: id));
    }
    for (final code in [publicCode, tvCode]) {
      final key = code?.trim().toUpperCase() ?? '';
      if (key.isEmpty) continue;
      // The public and TV codes share one namespace (E7), and a game that was
      // never re-rolled can hold the same value in both slots. `joinCodes/{code}`
      // is a single document, so a second delete of it is redundant work the
      // rules would evaluate again.
      if (refs.any((r) => r.collection == 'joinCodes' && r.id == key)) continue;
      refs.add((collection: 'joinCodes', id: key));
    }
    return refs;
  }

  /// Of [refs], only the ones whose document is actually there.
  ///
  /// This is not an optimisation, it is a correctness requirement. A delete of
  /// a document that does not exist is NOT a no-op in the rules engine: the
  /// rule is still evaluated, `resource` is null, and `resource.data.gid` on a
  /// null `resource` is a rules error, so the rule denies — and one denied
  /// write fails the WHOLE batch. Every rule these refs are deleted under reads
  /// `resource.data`, which is available and populated on a delete precisely
  /// because the document is there; it is only the missing-document case that
  /// breaks. Both collections are world-readable, so these are plain `get()`s.
  static Future<List<DocumentReference<Map<String, dynamic>>>> _existingRefs(
    List<DocumentReference<Map<String, dynamic>>> refs,
  ) async {
    // Bounded fan-out: a group with a long history yields hundreds of these and
    // a burst that wide is its own failure mode.
    const fanOut = 20;
    final found = <DocumentReference<Map<String, dynamic>>>[];
    for (var i = 0; i < refs.length; i += fanOut) {
      final window = refs.skip(i).take(fanOut).toList();
      final snaps = await Future.wait(window.map((r) => r.get()));
      for (var j = 0; j < window.length; j++) {
        if (snaps[j].exists) found.add(window[j]);
      }
    }
    return found;
  }

  /// B9: deletes a group and everything under it.
  ///
  /// Firestore's `delete()` on a document does NOT touch its subcollections, so
  /// a plain delete of `groups/{gid}` would leave the roster, every night, all
  /// the chat, the reports and the imported history readable to anyone who
  /// already had a membership row. Hence the walk.
  ///
  /// Two ordering facts make this a single batch rather than a loop of writes:
  ///
  ///  * Every rule here is `isGroupAdmin(gid)`, which reads BOTH the group doc
  ///    and the caller's own member row. If those were deleted in separate
  ///    writes, the second write would be evaluated against a group that no
  ///    longer exists and would be refused -- and the owner's own row is itself
  ///    one of the rows being deleted.
  ///  * Firestore evaluates every rule in a batch against the state *before* the
  ///    batch commits, so one batch authorises cleanly whatever the order
  ///    inside it. The group doc is queued last anyway so a partial failure
  ///    leaves the group intact rather than a headless one.
  ///
  /// The rows OUTSIDE the group are not optional extras, and they carry the same
  /// ordering constraint as everything else. `publicGames/{gameId}` and
  /// `joinCodes/{code}` delete under `isGroupOwner(resource.data.gid)` (or, for a
  /// code, `request.auth.uid == resource.data.ownerId`), and `isGroupOwner`
  /// reads `groups/{gid}` -- so they authorise only while the group document
  /// still exists. That is why they are queued above the final
  /// `deletes.add(groupRef)`, and why they may never be moved below it.
  ///
  /// `resource.data` is available on a delete of a document that is there, which
  /// is what every rule here reads, and is null for one that is not -- so the
  /// hand-named rows outside the group are presence-checked first ([_existingRefs])
  /// rather than deleted blind. A rules error in any one write denies the whole
  /// batch it is in, and a denied batch leaves the group half-deleted.
  ///
  /// `groups/{gid}` stays the very last element of [deletes], which makes it the
  /// last element of the LAST chunk. That is what makes the 500-per-batch
  /// chunking below safe for a group of any size: every earlier chunk is
  /// evaluated while `groups/{gid}` still exists, and within the final chunk
  /// every rule is evaluated against the pre-batch state, so the group document
  /// authorizes its own delete. Only the caller's OWN member row is a second
  /// dependency, and `deleteGroup` is owner-only
  /// (`AppProvider.deleteGroup` compares the uid against `group.ownerId`), so
  /// `isGroupAdmin` short-circuits on the `ownerId` disjunct for the whole walk
  /// — deleting the roster in an earlier chunk cannot strand a later one.
  ///
  /// Chunked at 500 writes, the batch limit.
  Future<void> deleteGroupRecursive(String gid, {String? joinCode}) async {
    final groupRef = _db.collection('groups').doc(gid);
    final deletes = <DocumentReference>[];

    Future<void> addAll(DocumentReference parent, String collection) async {
      final snap = await parent.collection(collection).get();
      for (final doc in snap.docs) {
        deletes.add(doc.reference);
      }
    }

    /// A collection that may itself hold subcollections.
    Future<void> addTree(
      DocumentReference parent,
      String collection,
      List<String> nested, {
      void Function(DocumentSnapshot<Map<String, dynamic>> doc)? onDoc,
    }) async {
      final snap = await parent.collection(collection).get();
      for (final doc in snap.docs) {
        deletes.add(doc.reference);
        onDoc?.call(doc);
        for (final sub in nested) {
          await addAll(doc.reference, sub);
        }
      }
    }

    // Every row OUTSIDE the group, named by hand rather than walked. Collected
    // here rather than lazily, because after the walk the game documents are
    // about to be deleted and their codes are the only remaining record of them.
    final external = <ExternalRef>[];

    /// A code read off a stored game, tolerating both a document that never had
    /// one and one that carries a non-string. A bad cast here would abort the
    /// whole walk and orphan every row this call exists to clean up — the one
    /// place where being lenient costs nothing and being strict is expensive.
    String? codeOf(DocumentSnapshot<Map<String, dynamic>> doc, String key) {
      final value = doc.data()?[key];
      return value is String ? value : null;
    }

    // Groups with real history have games with their own subcollections; the
    // list mirrors the nesting in firestore.rules.
    await addTree(groupRef, 'games', const [
      'memberViews',
      'players',
      'chat',
      'admin',
      'meta',
    ], onDoc: (doc) {
      external.addAll(externalGameRefs(
        gameId: doc.id,
        publicCode: codeOf(doc, 'publicCode'),
        tvCode: codeOf(doc, 'tvCode'),
      ));
    });
    for (final collection in const [
      'members',
      'chat',
      'reports',
      'importedNights',
      'polls',
      'cashSessions',
      'notifications',
    ]) {
      await addAll(groupRef, collection);
    }

    // The request queue is top-level and keyed by GAME, not by group, so the
    // walk above never sees it. Each item is a guest slot claim or a member's
    // rebuy/add-on/check-in request, and it carries the requester's name — so
    // an orphaned queue is personal data belonging to a group that no longer
    // exists, readable by the person who made the claim and by nobody who could
    // now clear it.
    //
    // This one is a QUERY rather than a hand-named row, and the rules allow it:
    // `requests/{gameId}/items/{reqId}` has `allow list: if isGroupAdmin(gid)`
    // evaluated per returned document, so constraining on `gid` proves the
    // result set, and `allow delete: if isGroupAdmin(gid)` authorises the
    // deletes. The caller is the owner, so both hold.
    final requestSnaps = await _db
        .collection('requests')
        .where('gid', isEqualTo: gid)
        .get();
    for (final requestDoc in requestSnaps.docs) {
      await addAll(requestDoc.reference, 'items');
    }

    // `pendingInvites/{inviteId}` is deliberately NOT cleaned here, and this is
    // a rules limit rather than an oversight. Every row's read rule is
    // `resource.data.uid == request.auth.uid`, so a `where('gid', ...)` query
    // can only ever return the CALLER's own invitations -- the owner has no way
    // to enumerate, let alone delete, invitations the group admin sent to
    // somebody else. There is no client-side fix: it needs either the rows to
    // live under `groups/{gid}` (a data-model migration) or a server-side
    // sweep, which is out of scope. The residue is a dead invitation pointing
    // at a group that no longer exists, readable only by the person it was sent
    // to.

    // The public invite row outlives the group otherwise, and the code would
    // still resolve to a name and a member count for a group nobody can enter.
    if (joinCode != null && joinCode.trim().isNotEmpty) {
      external.add((
        collection: 'joinCodes',
        id: joinCode.trim().toUpperCase(),
      ));
    }

    // A game's projection and its two codes are the same leak one level up: the
    // projection is readable by anyone, and each code still resolves to a
    // group and a game that are being deleted in this same walk. As is the
    // group's own invite row above.
    //
    // Every one of these is named rather than walked, so every one of them may
    // ALREADY be gone — E7 releases a game's projection and both its codes once
    // the game completes or is cancelled, and `updateGroupJoinCode` deletes the
    // previous row. A delete of a document that is not there is not a no-op in
    // the rules engine: the rule is still evaluated, `resource` is null, and
    // `resource.data.gid` on a null `resource` is a rules error, so the rule
    // denies — and one denied write fails the WHOLE batch, including every
    // other row queued with it. `resource.data` is available and populated for
    // every row that IS there, which is the only case that reaches a rule.
    // Both collections are `allow get: if true`, so the presence check is a
    // plain read and needs no authority of its own.
    //
    // A Set, so a code that two games somehow share — or a game code equal to
    // the group's invite code — is one delete rather than the same rule
    // evaluated twice for one document.
    if (external.isNotEmpty) {
      deletes.addAll(await _existingRefs([
        for (final ref in external.toSet())
          _db.collection(ref.collection).doc(ref.id),
      ]));
    }

    // MUST STAY LAST — see the ordering notes above.
    deletes.add(groupRef);

    for (var i = 0; i < deletes.length; i += 500) {
      final batch = _db.batch();
      for (final ref in deletes.skip(i).take(500)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  /// Atomically transfers group ownership to [newOwnerId]: updates the group
  /// doc's `ownerId` field and promotes the new owner's member row to `admin`.
  Future<void> transferGroupOwnership(
    String gid,
    String oldOwnerId,
    String newOwnerId,
    String newOwnerName,
  ) async {
    final batch = _db.batch();
    batch.update(_db.collection('groups').doc(gid), {'ownerId': newOwnerId});
    batch.set(
      _db.collection('groups').doc(gid).collection('members').doc(newOwnerId),
      {'name': newOwnerName, 'role': 'admin'},
      SetOptions(merge: true),
    );
    batch.set(
      _db.collection('groups').doc(gid).collection('members').doc(oldOwnerId),
      {'role': 'member'},
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  /// Looks up a registered user by exact (case-insensitive) email match, for
  /// the admin "add member directly" flow. Reads the public `emailIndex`
  /// (the `users` collection is private to each owner). Returns null when no
  /// account uses that email.
  Future<AppUser?> findUserByEmail(String email) async {
    final key = email.trim().toLowerCase();
    if (key.isEmpty) return null;
    final snap = await _db
        .collection('emailIndex')
        .doc(emailIndexKey(key))
        .get();
    final uid = snap.data()?['uid'] as String?;
    if (uid == null || uid.isEmpty) return null;
    return AppUser(
      id: uid,
      name: (snap.data()?['name'] as String?) ?? '',
      email: email.trim(),
      isAdmin: false,
      stats: const UserStats(
        played: 0,
        wins: 0,
        podium: 0,
        avgFinish: 0,
        knockouts: 0,
      ),
    );
  }

  /// Group admin adds a registered user directly. Writes the member row AND a
  /// `pendingInvites` doc (free plan — no Cloud Function, so `onMemberWrite`
  /// cannot mirror into the target user's /users tree; the added user instead
  /// reads their own pending invite on next open and self-writes their index).
  Future<void> addMemberToGroup(
    String gid,
    AppUser user, {
    String groupName = '',
    String groupIcon = '♠',
  }) async {
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
    batch.set(_db.collection('pendingInvites').doc('$gid:${user.id}'), {
      'uid': user.id,
      'gid': gid,
      'name': groupName,
      'icon': groupIcon,
      'role': 'member',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Live stream of this user's pending group invites. Each invite carries the
  /// group id + name/icon so the client can self-write its own membership index
  /// without needing to read `groups/{gid}` (which is member-only).
  Stream<List<Map<String, dynamic>>> pendingInvitesStream(String uid) => _db
      .collection('pendingInvites')
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs) {...d.data(), '__inviteId': d.id},
        ],
      );

  /// Removes a pending invite once the user has accepted (self-mirrored) it.
  Future<void> removePendingInvite(String inviteId) =>
      _db.collection('pendingInvites').doc(inviteId).delete();

  /// Per-caller clock-calibration document.
  ///
  /// Calibration used to write the SHARED `_meta/serverTime` document, whose
  /// rule constrained only the key set — so any signed-in client, anonymous
  /// guests included, could write an arbitrary timestamp and poison every
  /// other device's offset, including the admin's, which drives `levelEndTime`
  /// for the whole tournament (Technical section 4.3, 19-008). Each caller now
  /// owns its own document and the rule pins the value to `request.time`.
  DocumentReference<Map<String, dynamic>> get serverTimeRef => _db
      .collection('_meta')
      .doc('clock')
      .collection('users')
      .doc(currentUid ?? 'anon');

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
        controller.add(
          Group(
            id: gid,
            name: (meta?['name'] as String?) ?? '',
            joinCode: (meta?['joinCode'] as String?) ?? '',
            ownerId: (meta?['ownerId'] as String?) ?? '',
            icon: (meta?['icon'] as String?) ?? '♠',
            members: members,
            chat: chat,
            polls: polls,
            games: games,
            notifications: const [],
            tableSettings: meta?['tableSettings'] == null
                ? TableSettings.fallback
                : tableSettingsFromMap(
                    Map<String, dynamic>.from(meta!['tableSettings'] as Map),
                  ),
          ),
        );
      }
    }

    final groupRef = _db.collection('groups').doc(gid);
    final retryTimers = <String, Timer>{};

    // Each section subscribes independently. A section that errors (a rule
    // denies one subcollection, or — the common case — the auth token has not
    // yet propagated into the Firestore SDK in the seconds right after a web
    // login/join) is marked "loaded" so [maybeEmit] can still deliver the rest
    // of the group and the UI leaves its loading state. Crucially it then keeps
    // RE-SUBSCRIBING with backoff: a permission-propagation gap clears within a
    // few seconds and the section fills in on its own, so the user no longer
    // has to reload the page to see their games.
    void section<S>(
      String name,
      Stream<S> Function() open,
      void Function(S snap) apply,
      void Function() markLoaded,
    ) {
      var attempt = 0;
      void subscribe() {
        subs.add(
          open().listen(
            (s) {
              attempt = 0;
              retryTimers.remove(name)?.cancel();
              apply(s);
              markLoaded();
              maybeEmit();
            },
            onError: (Object e, StackTrace _) {
              debugPrint('groupBundle "$name" error: $e');
              markLoaded();
              maybeEmit();
              if (attempt < 8 && !controller.isClosed) {
                // Post-login token lag is the common cause — nudge a fresh token
                // into the SDK before re-subscribing.
                if (e.toString().contains('permission-denied') ||
                    e.toString().contains('unauthenticated')) {
                  _auth.currentUser
                      ?.getIdToken(true)
                      .catchError((Object _) => '');
                }
                final delayMs = 400 * (1 << (attempt > 5 ? 5 : attempt));
                attempt++;
                retryTimers[name]?.cancel();
                retryTimers[name] = Timer(
                  Duration(milliseconds: delayMs),
                  subscribe,
                );
              }
            },
          ),
        );
      }

      subscribe();
    }

    controller = StreamController<Group>(
      onListen: () {
        section<DocumentSnapshot<Map<String, dynamic>>>(
          'meta',
          () => groupRef.snapshots(),
          (s) => meta = s.data(),
          () => metaLoaded = true,
        );
        section<QuerySnapshot<Map<String, dynamic>>>(
          'members',
          () => groupRef.collection('members').snapshots(),
          (s) => members = [
            for (final d in s.docs)
              AppUser(
                id: d.id,
                name: (d.data()['name'] as String?) ?? '',
                email: '',
                isAdmin: (d.data()['role'] as String?) == 'admin',
                isCoAdmin: (d.data()['role'] as String?) == 'coadmin',
                stats: d.data()['stats'] is Map
                    ? userStatsFromMap(
                        Map<String, dynamic>.from(d.data()['stats'] as Map),
                      )
                    : const UserStats(
                        played: 0,
                        wins: 0,
                        podium: 0,
                        avgFinish: 0,
                        knockouts: 0,
                      ),
              ),
          ],
          () => membersLoaded = true,
        );
        section<QuerySnapshot<Map<String, dynamic>>>(
          'chat',
          () => groupRef.collection('chat').snapshots(),
          (s) => chat = [for (final d in s.docs) chatMessageFromMap(d.data())],
          () => chatLoaded = true,
        );
        section<QuerySnapshot<Map<String, dynamic>>>(
          'polls',
          () => groupRef.collection('polls').snapshots(),
          (s) => polls = [for (final d in s.docs) pollFromMap(d.data())],
          () => pollsLoaded = true,
        );
        section<QuerySnapshot<Map<String, dynamic>>>(
          'games',
          () => groupRef
              .collection('games')
              .orderBy('settings.date', descending: true)
              .limit(15)
              .snapshots(),
          (s) => games = [for (final d in s.docs) ?tryParseGameDoc(d)],
          () => gamesLoaded = true,
        );
      },
      onCancel: () async {
        for (final t in retryTimers.values) {
          t.cancel();
        }
        retryTimers.clear();
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return controller.stream;
  }

  /// Parses a group game document defensively: a single malformed doc used to
  /// blank the whole games list (hub + chat card lookups). Returns null and
  /// logs so the rest of the bundle keeps loading.
  LiveGame? tryParseGameDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    try {
      return liveGameFromFirestoreDoc(Map<String, dynamic>.from(d.data()));
    } catch (e) {
      debugPrint('groupBundle: skipping malformed game doc ${d.id}: $e');
      return null;
    }
  }

  Future<void> sendGroupChatMessage(String gid, ChatMessage msg) async {
    final batch = _db.batch();
    batch.set(
      _db.collection('groups').doc(gid).collection('chat').doc(msg.id),
      chatMessageToMap(msg),
    );
    batch.set(_db.collection('rate_limits').doc('chat-${msg.authorId}'), {
      'time': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  // ── Reports (groups/{gid}/reports) ─────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> _reportsCol(String gid) =>
      _db.collection('groups').doc(gid).collection('reports');

  /// Files a report. The id is `<messageId>_<reporterUid>`, so the same member
  /// reporting the same message twice is refused by the rules (create-only)
  /// rather than duplicated.
  Future<void> reportChatMessage(String gid, ChatReport report) =>
      _reportsCol(gid).doc(report.id).set({
        ...report.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

  /// Admin-only: reads are denied to plain members by the rules.
  Stream<List<ChatReport>> reportsStream(String gid) =>
      _reportsCol(gid).snapshots().map((s) {
        final list = [
          for (final d in s.docs)
            ChatReport.fromMap(
              d.id,
              d.data(),
              (d.data()['createdAt'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
            ),
        ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  Future<void> clearReport(String gid, String reportId) =>
      _reportsCol(gid).doc(reportId).delete();

  // ── Imported nights (groups/{gid}/importedNights, B12) ─────────────────────
  CollectionReference<Map<String, dynamic>> _importedNightsCol(String gid) =>
      _db.collection('groups').doc(gid).collection('importedNights');

  /// Host-only (rules). One batch, so a failed import leaves nothing behind.
  Future<void> saveImportedNights(String gid, List<ImportedNight> nights) async {
    final batch = _db.batch();
    for (final n in nights) {
      batch.set(_importedNightsCol(gid).doc(n.id), n.toMap());
    }
    await batch.commit();
  }

  /// Readable by every member, oldest night first.
  Stream<List<ImportedNight>> importedNightsStream(String gid) =>
      _importedNightsCol(gid).snapshots().map((s) {
        final list = [
          for (final d in s.docs) ImportedNight.fromMap(d.id, d.data()),
        ]..sort((a, b) => a.date.compareTo(b.date));
        return list;
      });

  Future<void> markChatMessageDeleted(String gid, String msgId) => _db
      .collection('groups')
      .doc(gid)
      .collection('chat')
      .doc(msgId)
      .set({'deleted': true}, SetOptions(merge: true));

  // ── Per-game chat (groups/{gid}/games/{gameId}/chat) ───────────────────────
  // A subcollection the host and every member append to directly, so a
  // member's message is not rolled back by the game-doc rules and does not
  // wait on a projection round-trip.
  CollectionReference<Map<String, dynamic>> _gameChatCol(
    String gid,
    String gameId,
  ) => _db
      .collection('groups')
      .doc(gid)
      .collection('games')
      .doc(gameId)
      .collection('chat');

  Stream<List<ChatMessage>> gameChatStream(String gid, String gameId) =>
      _gameChatCol(gid, gameId).snapshots().map(
        (s) => [for (final d in s.docs) chatMessageFromMap(d.data())],
      );

  Future<void> sendGameChatMessage(
    String gid,
    String gameId,
    ChatMessage msg,
  ) async {
    final batch = _db.batch();
    batch.set(_gameChatCol(gid, gameId).doc(msg.id), chatMessageToMap(msg));
    batch.set(_db.collection('rate_limits').doc('chat-${msg.authorId}'), {
      'time': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> markGameChatMessageDeleted(
    String gid,
    String gameId,
    String msgId,
  ) => _gameChatCol(
    gid,
    gameId,
  ).doc(msgId).set({'deleted': true}, SetOptions(merge: true));

  /// Writes a poll. A member VOTE also stamps the throttle document the rules
  /// require (19-010) in the same batch, so the rule's `getAfter` observes it.
  /// Admin writes (create / close) are not throttled.
  Future<void> savePoll(String gid, Poll poll, {bool asVote = false}) async {
    final ref = _db.collection('groups').doc(gid).collection('polls').doc(poll.id);
    final uid = currentUid;
    if (!asVote || uid == null) {
      await ref.set(pollToMap(poll));
      return;
    }
    final batch = _db.batch();
    batch.set(ref, pollToMap(poll));
    batch.set(_db.collection('rate_limits').doc('vote-$uid'), {
      'time': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  // ── Games ──────────────────────────────────────────────────────────────────
  /// Atomically declares this device the single active editor for [gameId].
  ///
  /// Closes the editor-claim race: two admins opening a fresh game in the same
  /// millisecond cannot both become the whole-document writer, because only one
  /// transaction can observe `editorDeviceId` empty/stale and set it. The
  /// loser reads the freshly-claimed device id and gets an aborted error.
  /// Returns true when this device won the claim. (The claim timestamp is
  /// persisted as an ISO string to match `liveGameToFirestoreDoc`'s
  /// `editorClaimedAt` encoding.)
  Future<bool> claimGameEditor(String groupId, String gameId, {bool force = false}) {
    final ref = _db
        .collection('groups')
        .doc(groupId)
        .collection('games')
        .doc(gameId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        final data = snap.data()!;
        final serverEditor = data['editorDeviceId'] as String?;
        final serverClaimed = data['editorClaimedAt'] as String?;
        if (serverEditor != null && serverEditor.isNotEmpty) {
          final sameDevice = serverEditor == deviceId;
          final stale =
              serverClaimed != null &&
              DateTime.now().difference(
                    DateTime.tryParse(serverClaimed) ?? DateTime.now(),
                  ) >
                  const Duration(seconds: 90);
          // Held by an active editor (or this device already owns it) — no claim.
          if (!force && (sameDevice || !stale)) throw Exception('aborted');
        }
      }
      // Newly created games have no document yet; `tx.update` on a missing
      // doc fails the transaction, so the editor role was never claimed and the
      // authority gate then blocked every first save — the game never reached
      // Firestore. A merge-set creates the claim stub when missing and behaves
      // like a plain field update when the doc already exists.
      tx.set(ref, {
        'editorDeviceId': deviceId,
        'editorClaimedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      return true;
    });
  }

  /// Writes the whole game document, merging member-owned fields ATOMICALLY.
  ///
  /// Returns the game as it was actually written, which may differ from
  /// [game]: [reconcile] folds in anything the members changed while this
  /// edit was in flight.
  ///
  /// The merge has to happen INSIDE the transaction. It used to be a separate
  /// `gameDocOnce` read moments earlier, which left a window a whole network
  /// round trip wide between "read what the members did" and "write the whole
  /// document" - and anything landing in that window was silently overwritten
  /// by the `.set()`.
  ///
  /// That window opened at the worst possible moment. Tapping "Open check-in"
  /// triggers a save, and opening check-in is precisely what makes members tap
  /// Check In. Their patch landed mid-save, the admin's write reverted
  /// `checkedIn` to false, the member's optimistic overlay kept showing them
  /// as checked in, and the host's queue stayed empty. It recovered only when
  /// `_maybeReassertOwnCheckIn` re-sent the patch after some later change -
  /// the "it works the second time" symptom.
  Future<LiveGame> saveGame(
    LiveGame game, {
    String? viewerId,
    bool isUpdate = true,
    int? expectedRevision,
    bool force = false,
    LiveGame Function(LiveGame local, LiveGame remote)? reconcile,
  }) async {
    final gameRef = _db
        .collection('groups')
        .doc(game.groupId)
        .collection('games')
        .doc(game.id);

    // The game as actually committed - [game] plus whatever the transaction
    // merged in. Read back after the transaction returns.
    var written = game;

    await _db.runTransaction((tx) async {
      // Reset per attempt: a transaction body can run more than once.
      written = game;

      // One read serves the concurrency guards AND the merge. Firestore
      // requires every read before any write, so it happens up front.
      final needsRead =
          reconcile != null || (expectedRevision != null && !force);
      DocumentSnapshot<Map<String, dynamic>>? snap;
      if (needsRead) snap = await tx.get(gameRef);

      // `force` is the blocking-action override (currently: cancelling a
      // tournament). It means "this device is taking over", so it bypasses
      // BOTH concurrency guards below, not just the editor claim. A cancel
      // that loses a revision race must still land: the event is over.
      if (expectedRevision != null && !force && snap != null && snap.exists) {
        final data = snap.data()!;
        final currentRevision = (data['revision'] as num?)?.toInt() ?? 0;
        if (currentRevision != expectedRevision) {
          throw fa.FirebaseException(
            plugin: 'cloud_firestore',
            code: 'aborted',
            message:
                'Game revision mismatch. Expected $expectedRevision, got $currentRevision.',
          );
        }
        final serverEditor = data['editorDeviceId'] as String?;
        if (serverEditor != null &&
            serverEditor.isNotEmpty &&
            serverEditor != deviceId) {
          final serverClaimed = parseEditorClaimedAt(data['editorClaimedAt']);
          final now = DateTime.now();
          // Unparseable / missing stamp counts as stale: never let a claim we
          // cannot date block the authority device forever.
          final isStale =
              serverClaimed == null ||
              now.difference(serverClaimed) > const Duration(seconds: 90);
          if (!isStale) {
            throw fa.FirebaseException(
              plugin: 'cloud_firestore',
              code: 'aborted',
              message: 'Another host is actively editing this game.',
            );
          }
        }
      }

      // Fold in the members' own fields from the copy just read, so nothing
      // committed since this edit began can be lost.
      if (reconcile != null && snap != null && snap.exists) {
        try {
          final remote = liveGameFromFirestoreDoc(
            Map<String, dynamic>.from(snap.data()!),
          );
          if (remote.id == game.id) written = reconcile(game, remote);
        } catch (e) {
          debugPrint('saveGame: could not decode remote for merge: $e');
        }
      }

      tx.set(gameRef, _stamp(_publicGameDoc(written, viewerId)));
    });

    // Admin-only sidecar, written from the MERGED game so the host's private
    // copy matches what everyone else can see. Its rule requires the strict
    // `isGroupAdmin(gid)` while the public document only requires membership;
    // letting a sidecar rejection abort the whole call meant one permission
    // mismatch silently discarded every game update, so it is logged and
    // skipped instead. Losing the private figures is recoverable; losing the
    // game state is not.
    try {
      await gameRef
          .collection('admin')
          .doc('privateData')
          .set(_privateGameDoc(written), SetOptions(merge: true));
    } catch (e) {
      debugPrint('saveGame: private sidecar rejected (continuing): $e');
    }

    await _mirrorPlayerIndex(gameRef, written);

    return written;
  }

  /// Number of players occupying a seat right now — the figure addendum §3
  /// caps at nine for free hosting ("one table / max 9 active players").
  ///
  /// Matches `Entitlements.canHost`'s definition exactly: somebody who busted
  /// out has freed their seat, so they no longer count against the cap.
  static int activePlayerCount(LiveGame game) =>
      game.players.where((p) => p.active && !p.eliminated).length;

  /// Stage 1 of the free-tier cap migration: mirror the players map into a
  /// real subcollection plus a counter document.
  ///
  /// Why this exists at all. The cap is enforced today only by
  /// `Entitlements.canHost` in Dart, which ships to the device and can be
  /// deleted from a rebuilt client. It cannot be enforced in security rules
  /// as things stand, because `players` is a MAP FIELD inside the one game
  /// document and the rules language has no loop — it cannot count how many
  /// entries have `active == true && eliminated == false`, so it has nothing
  /// to compare against nine.
  ///
  /// A counter alone does not fix that either: a rule still could not tell
  /// whether a self-reported number matched the map it claims to describe.
  /// What makes it enforceable is giving each player their OWN document, so
  /// that ADDING a player becomes its own discrete write with its own rule —
  /// one that can require, via `getAfter`, that the counter moved up by
  /// exactly one in the same atomic commit. Player ten then cannot be created
  /// at all, because the commit that would register them is refused by
  /// Firestore rather than skipped by app code.
  ///
  /// This method is deliberately WRITE-ONLY and best-effort. Nothing reads
  /// these documents yet and no rule enforces them yet; the live app still
  /// runs entirely off the `players` map. That is what makes this stage safe
  /// to ship on its own — if the mirror is wrong or missing, nothing breaks.
  Future<void> _mirrorPlayerIndex(
    DocumentReference<Map<String, dynamic>> gameRef,
    LiveGame game,
  ) async {
    try {
      final batch = _db.batch();
      for (final p in game.players) {
        batch.set(gameRef.collection('players').doc(p.id), {
          ...playerToMap(p),
          'gameId': game.id,
          'groupId': game.groupId,
        }, SetOptions(merge: true));
      }
      batch.set(gameRef.collection('meta').doc('playerCount'), {
        'active': activePlayerCount(game),
        'total': game.players.length,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      await batch.commit();
    } catch (e) {
      // Stage 1 is a shadow copy. A rejection here must never cost the host
      // their game state, exactly as with the private sidecar above.
      debugPrint('saveGame: player index mirror skipped: $e');
    }
  }

  /// Admin-only companion document: everything scrubbed out of the public one.
  Map<String, dynamic> _privateGameDoc(LiveGame game) {
    final fullDoc = liveGameToFirestoreDoc(game);
    return <String, dynamic>{
      'organizerPct': game.settings.organizerPct,
      // The full players array travels here because the public doc scrubs
      // per-player financial fields (User Flow sections 2.3 / 5.6).
      'players': game.players.map(playerToMap).toList(),
      // Admin-only audit timeline (User Flow section 11).
      'auditHistory': fullDoc['auditHistory'],
      // Pending rebuy / add-on requests name the members who asked (section
      // 5.6 / section 22), so the queue is admin-side state.
      'rebuyRequests': fullDoc['rebuyRequests'],
      'addOnRequests': fullDoc['addOnRequests'],
      'prizes': fullDoc['structure']['prizes'],
      'organizerAmount': fullDoc['structure']['organizerAmount'],
    };
  }

  /// The member-readable game document: everything private removed BEFORE the
  /// write, because members read this document directly and a client-side
  /// projection is not a boundary (User Flow section 2.3).
  Map<String, dynamic> _publicGameDoc(LiveGame game, String? viewerId) {
    final publicDoc = Map<String, dynamic>.from(liveGameToFirestoreDoc(game));

    publicDoc['auditHistory'] = const <Map<String, dynamic>>[];
    publicDoc['rebuyRequests'] = const <String>[];
    publicDoc['addOnRequests'] = const <String>[];
    // A2-1: who declined an add-on is per-person financial intent, so it sits
    // with the request queues rather than in the member-readable document.
    publicDoc['addOnDeclined'] = const <String>[];

    final publicSettings = Map<String, dynamic>.from(
      publicDoc['settings'] as Map? ?? {},
    );
    publicSettings.remove('organizerPct');
    // The overtime badge is host-side settlement state, not play state. The
    // rules require this to be absent (publicGameDocSafe), so the client has
    // to strip it too or every authority write is refused.
    publicSettings.remove('addOnOvertime');
    publicDoc['settings'] = publicSettings;

    if (publicDoc['structure'] != null) {
      final publicStructure = Map<String, dynamic>.from(
        publicDoc['structure'] as Map,
      );
      // D2: "Everyone - players, guests, the TV - sees the prize pool and the
      // payouts. Only the host's organiser contribution stays hidden." So the
      // payout ladder stays on the member-readable document; only
      // `organizerAmount` is removed. This reverses the earlier decision to
      // omit the whole `prizes` list, which made every non-host see an empty
      // ladder while the spec promises them the amounts.
      publicStructure.remove('organizerAmount');
      publicDoc['structure'] = publicStructure;
    }

    // Per-player financial fields are private (Technical section 5.6), the
    // writer's own row included - 14-045 / 05-033 / 19-021 say a player does
    // not see their own investment either.
    if (publicDoc['players'] is Map) {
      final publicPlayers = Map<String, dynamic>.from(
        publicDoc['players'] as Map,
      );
      final scrubbed = <String, dynamic>{};
      for (final e in publicPlayers.entries) {
        final value = Map<String, dynamic>.from(e.value as Map);
        value['rebuys'] = 0;
        value['reEntries'] = 0;
        value['hasAddOn'] = false;
        value['knockouts'] = 0;
        scrubbed[e.key] = value;
      }
      publicDoc['players'] = scrubbed;
    }
    return publicDoc;
  }

  /// Decodes an `editorClaimedAt` value from a game document.
  ///
  /// Every writer stores it as an ISO-8601 STRING (`claimGameEditor`, the
  /// heartbeat dot-patch in `_claimEditorIfNeeded`, and
  /// `liveGameToFirestoreDoc`'s `_nullOrIso`). Reading it back as a
  /// `Timestamp` therefore threw a `TypeError` inside the save transaction on
  /// every admin write after the first one — surfaced to the host as
  /// "Changes could not be saved. Check your connection." and silently
  /// reverting the edit (most visibly: cancelling a tournament). Accept the
  /// legacy `Timestamp` shape too so documents written by older builds still
  /// decode.
  @visibleForTesting
  static DateTime? parseEditorClaimedAt(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  /// Saves the admin's undo history to a sidecar subcollection so it travels
  /// with the account across devices, without forcing players to download it.
  Future<void> saveUndoStack(
    String groupId,
    String gameId,
    List<LiveGame> stack,
  ) => _db
      .collection('groups')
      .doc(groupId)
      .collection('games')
      .doc(gameId)
      .collection('admin')
      .doc('undoStack')
      .set({'snapshots': stack.map(liveGameToFirestoreDoc).toList()});

  /// Loads the admin's undo history sidecar document.
  Future<List<LiveGame>> loadUndoStack(String groupId, String gameId) async {
    final doc = await _db
        .collection('groups')
        .doc(groupId)
        .collection('games')
        .doc(gameId)
        .collection('admin')
        .doc('undoStack')
        .get();
    if (!doc.exists) return [];

    final snapshots = doc.data()?['snapshots'] as List?;
    if (snapshots == null) return [];

    return snapshots
        .map((s) => liveGameFromFirestoreDoc(s as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>?> loadPrivateGameData(
    String groupId,
    String gameId,
  ) async {
    final snap = await _db
        .collection('groups')
        .doc(groupId)
        .collection('games')
        .doc(gameId)
        .collection('admin')
        .doc('privateData')
        .get();
    return snap.data();
  }

  Map<String, dynamic> _unflatten(Map<String, dynamic> flat) {
    final unflattened = <String, dynamic>{};
    for (final entry in flat.entries) {
      final parts = entry.key.split('.');
      Map<String, dynamic> current = unflattened;
      for (var i = 0; i < parts.length - 1; i++) {
        final part = parts[i];
        current[part] ??= <String, dynamic>{};
        current = current[part] as Map<String, dynamic>;
      }
      current[parts.last] = entry.value;
    }
    return unflattened;
  }

  /// Targeted per-player / field patches using Firestore dot-paths — avoids
  /// clobbering unrelated concurrent edits (e.g. RSVPs while admin edits).
  ///
  /// MUST use `update()` (not `set(merge:true)`): a merge-set only merges at
  /// the TOP level, so `{players: {uid: ...}}` would REPLACE the whole
  /// `players` id-keyed map and wipe every other player's row — and the rules'
  /// `memberPlayersSafe` then rejects the write (permission-denied) because
  /// the diff touches every key. `update()` with dot-path keys deep-merges,
  /// touching only the member's own fields.
  Future<void> patchGame(
    String gid,
    String gameId,
    Map<String, dynamic> dotPaths,
  ) async {
    final ref = _db
        .collection('groups')
        .doc(gid)
        .collection('games')
        .doc(gameId);
    final patch = _stamp(dotPaths);
    try {
      await ref.update(patch);
    } on FirebaseException catch (e) {
      // A missing game doc (e.g. a legacy game never persisted) makes
      // update() fail with not-found. Fall back to a create carrying only the
      // member's own slice — the rules allow a member to create a game doc
      // when it contains exclusively their own rows (memberGameCreate).
      if (e.code == 'not-found') {
        await ref.set(_stamp(_unflatten(dotPaths)), SetOptions(merge: true));
      } else {
        rethrow;
      }
    }
  }

  /// Live game document. Both admins and members follow the raw doc — members
  /// are gated to `isMember(gid)` by rules and the app sanitizes payout /
  /// organizer figures for non-authority viewers before display. (The old
  /// per-member `memberViews` projection needed a Cloud Function to maintain
  /// it; this build runs without functions.)
  Stream<DocumentSnapshot<Map<String, dynamic>>> gameDocSnapshots(
    String gid,
    String gameId, {
    bool isAdmin = false,
  }) => _db
      .collection('groups')
      .doc(gid)
      .collection('games')
      .doc(gameId)
      .snapshots();

  /// One-shot read of the raw game document — used right before a whole-doc
  /// save to reconcile member-owned fields (RSVPs, guest slots) that may have
  /// changed while the admin's edit was debouncing.
  Future<Map<String, dynamic>?> gameDocOnce(String gid, String gameId) async {
    final snap = await _db
        .collection('groups')
        .doc(gid)
        .collection('games')
        .doc(gameId)
        .get();
    return snap.data();
  }

  /// Registers the game's public/tv codes for lookup flows.
  Future<void> upsertGameCodes(LiveGame game) async {
    final batch = _db.batch();
    batch.set(_db.collection('joinCodes').doc(game.publicCode.toUpperCase()), {
      'gid': game.groupId,
      'gameId': game.id,
      'kind': 'game',
    });
    batch.set(_db.collection('joinCodes').doc(game.tvCode.toUpperCase()), {
      'gid': game.groupId,
      'gameId': game.id,
      'kind': 'tv',
    });
    await batch.commit();
  }

  /// Writes sanitized projection payloads readable by non-members
  /// (TV mode browsers, guests) under publicGames/{gameId}.
  Future<void> publishPublicProjections({
    required LiveGame game,
    required Map<String, dynamic> tv,
    required Map<String, dynamic> player,
    required Map<String, dynamic> guest,
  }) => _db
      .collection('publicGames')
      .doc(game.id)
      .set(
        _stamp({
          'gid': game.groupId,
          'publicCode': game.publicCode,
          'tvCode': game.tvCode,
          'status': game.status.name,
          'tv': tv,
          'player': player,
          'guest': guest,
        }),
      );

  Stream<Map<String, dynamic>> publicGameStream(String gameId) => _db
      .collection('publicGames')
      .doc(gameId)
      .snapshots()
      .map((s) => s.data() ?? const {});

  /// Resolves a public/tv code to `(gid, gameId, kind)` or null.
  Future<({String gid, String gameId, String kind})?> findGameByCode(
    String code,
  ) async {
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
      // 19-010: claims are creatable by any anonymous caller, so without a
      // throttle one script could squat every slot in a game. Stamped inside
      // the same transaction the rule's `getAfter` observes.
      final uid = currentUid;
      if (uid != null) {
        tx.set(_db.collection('rate_limits').doc('guestclaim-$uid'), {
          'time': FieldValue.serverTimestamp(),
        });
      }
      return null;
    });
  }

  /// Deletes a slot-claim lock so the slot becomes claimable again (admin
  /// rejected the guest or freed the seat — user-flow spec §7.1).
  Future<void> releaseSlotClaim(String gameId, String inviterId, int slot) =>
      _requestsCol(gameId).doc('guestCheckIn-$inviterId-$slot').delete();

  Stream<List<GameRequest>> requestsStream(String gameId, String groupId) =>
      _requestsCol(gameId)
          .where('gid', isEqualTo: groupId)
          .where('consumed', isEqualTo: false)
          .snapshots()
          .map(
            (s) => [
              for (final d in s.docs)
                GameRequest(
                  id: d.id,
                  kind: (d.data()['kind'] as String?) ?? '',
                  payload: Map<String, dynamic>.from(d.data()),
                  createdAt:
                      (d.data()['createdAt'] as Timestamp?)?.toDate() ??
                      DateTime.now(),
                ),
            ],
          );

  Future<void> consumeRequest(String gameId, String requestId) => _requestsCol(
    gameId,
  ).doc(requestId).set({'consumed': true}, SetOptions(merge: true));

  // ── Cash sessions ──────────────────────────────────────────────────────────
  Future<void> saveCashSession(String gid, CashSession session) => _db
      .collection('groups')
      .doc(gid)
      .collection('cashSessions')
      .doc(session.id)
      .set(_stamp(cashSessionToMap(session)));

  Stream<List<CashSession>> completedCashSessionsStream(String gid) => _db
      .collection('groups')
      .doc(gid)
      .collection('cashSessions')
      .where('isCompleted', isEqualTo: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) cashSessionFromMap(d.data())]);

  // ── Solo games (no group) ──────────────────────────────────────────────────
  // A quick game finished with no group selected has nowhere under `groups/` to
  // live, so it is kept on the host's own user doc and shown in /history tagged
  // "Solo" (Addendum 1).
  Future<void> saveSoloSession(String uid, CashSession session) => _db
      .collection('users')
      .doc(uid)
      .collection('soloGames')
      .doc(session.id)
      .set(_stamp(cashSessionToMap(session)));

  Stream<List<CashSession>> soloSessionsStream(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('soloGames')
      .snapshots()
      .map((s) => [for (final d in s.docs) cashSessionFromMap(d.data())]);

  Future<void> saveSoloTournament(String uid, LiveGame game) => _db
      .collection('users')
      .doc(uid)
      .collection('soloTournaments')
      .doc(game.id)
      .set(_stamp(liveGameToMap(game)));

  Stream<List<LiveGame>> soloTournamentsStream(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('soloTournaments')
      .snapshots()
      .map((s) => [for (final d in s.docs) liveGameFromMap(d.data())]);

  // ── Presets / chip sets ────────────────────────────────────────────────────
  Future<void> savePreset(String uid, TournamentPreset preset) => _db
      .collection('users')
      .doc(uid)
      .collection('presets')
      .doc(preset.id)
      .set(tournamentPresetToMap(preset));

  Future<void> deletePreset(String uid, String presetId) => _db
      .collection('users')
      .doc(uid)
      .collection('presets')
      .doc(presetId)
      .delete();

  Stream<List<TournamentPreset>> presetsStream(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('presets')
      .snapshots()
      .map((s) => [for (final d in s.docs) tournamentPresetFromMap(d.data())]);

  Future<void> saveChipSet(
    String uid,
    String id,
    String name,
    List<ChipColor> chips,
  ) => _db.collection('users').doc(uid).collection('chipSets').doc(id).set({
    'name': name,
    'chips': chips.map(chipColorToMap).toList(),
  });

  Future<void> deleteChipSet(String uid, String id) =>
      _db.collection('users').doc(uid).collection('chipSets').doc(id).delete();

  Stream<List<({String id, String name, List<ChipColor> chips})>>
  chipSetsStream(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('chipSets')
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            (
              id: d.id,
              name: (d.data()['name'] as String?) ?? '',
              chips: (d.data()['chips'] as List? ?? const [])
                  .map(
                    (e) =>
                        chipColorFromMap(Map<String, dynamic>.from(e as Map)),
                  )
                  .toList(),
            ),
        ],
      );

  // ── Notification fan-out ───────────────────────────────────────────────────
  // FREE-PLAN fan-out (no Cloud Function, no Blaze plan):
  //  1. The originating device stages ONE notification in the group outbox.
  //  2. Every member device mirrors outbox items it hasn't seen into ITS OWN
  //     inbox — rules only allow the inbox owner to create docs.
  //  3. The originating device also fans the event out as a REAL push
  //     (OneSignal REST API, include_aliases = member uids).
  /// Serialises notification staging so the rules' throttle can never lose one.
  ///
  /// The rule requires a fresh `rate_limits/notify-{uid}` stamp, and the
  /// `rate_limits` update rule enforces a minimum gap. Two notifications
  /// closer together than that gap — an admin tapping through a queue of
  /// guest confirmations, or two eliminations in quick succession — made the
  /// SECOND batch fail, and it was dropped with only a debugPrint. The
  /// notification stayed in the sender's own inbox while never reaching
  /// anybody else's, which is the worst possible outcome for a throttle.
  ///
  /// Writes now queue behind one another with a safe spacing, so a burst is
  /// delayed rather than discarded.
  Future<void>? _notifyChain;
  DateTime? _lastNotifyAt;
  static const Duration _notifyGap = Duration(milliseconds: 1700);

  Future<void> stageGroupNotification(
    String gid,
    AppNotification notification,
  ) {
    final prev = _notifyChain ?? Future<void>.value();
    final next = prev
        .catchError((Object _) {})
        .then((_) async {
          final last = _lastNotifyAt;
          if (last != null) {
            final since = DateTime.now().difference(last);
            if (since < _notifyGap) await Future<void>.delayed(_notifyGap - since);
          }
          _lastNotifyAt = DateTime.now();
          await _stageGroupNotificationNow(gid, notification);
        });
    _notifyChain = next;
    return next;
  }

  Future<void> _stageGroupNotificationNow(
    String gid,
    AppNotification notification,
  ) async {
    final uid = currentUid;
    if (uid == null) return;
    final batch = _db.batch();
    batch.set(
      _db
          .collection('groups')
          .doc(gid)
          .collection('notifications')
          .doc(notification.id),
      _stamp({
        'title': notification.title,
        'body': notification.body,
        'type': notification.type.name,
        'link': notification.link,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        if (notification.audience != null && notification.audience!.isNotEmpty)
          'audience': notification.audience,
      }),
    );
    batch.set(_db.collection('rate_limits').doc('notify-$uid'), {
      'time': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Live stream of a group's staged-notification outbox.
  Stream<List<OutboxNotification>> groupOutboxStream(String gid) => _db
      .collection('groups')
      .doc(gid)
      .collection('notifications')
      .snapshots()
      .map(
        (s) => [
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
              timestamp:
                  (d.data()['timestamp'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
              updatedAtMillis:
                  (d.data()['updatedAt'] as Timestamp?)
                      ?.millisecondsSinceEpoch ??
                  0,
            ),
        ],
      );

  /// Mirrors a staged outbox notification into the signed-in user's OWN inbox.
  Future<void> mirrorInboxNotification(
    String uid,
    AppNotification notification, {
    bool read = false,
  }) => _db
      .collection('users')
      .doc(uid)
      .collection('notifications')
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
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .orderBy('timestamp', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => [for (final d in s.docs) appNotificationFromMap(d.data())]);

  Future<void> markNotificationRead(String uid, String notificationId) => _db
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .doc(notificationId)
      .set({'read': true}, SetOptions(merge: true));

  Future<void> markAllNotificationsRead(String uid) async {
    final docs = await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .get();
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
