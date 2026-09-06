/// AppProvider: Auth domain mixin.
///
/// Extracted verbatim from app_provider.dart (`// ── Auth ──`). Do not change business logic.
part of 'app_provider.dart';

extension AppProviderAuth on AppProvider {
  AppUser? get user => _user;

  bool get isAuthenticated => _user != null;

  /// True while the signed-in account is an anonymous (guest) session.
  bool get isGuest => _repo.isSignedInAsGuest;

  Future<void> _onAuthStateChanged(fa.User? fbUser) async {
    if (fbUser == null) {
      // Nothing to hydrate for a signed-out user — release the router now.
      _authReady = true;
      _teardownUserData();
      if (_user != null) {
        _user = null;
        notifyListeners();
      }
      return;
    }
    // Keep the router gated at splash until the restored session is actually
    // usable (profile + streams). Flipping `_authReady` before this made the
    // guard see `ready=true, authed=false` during hydration and bounce a
    // signed-in user to the login page until a rebuild happened (the "tap a
    // field / login button and it logs me in" bug).
    await _hydrateUser(fbUser);
    _authReady = true;
    _calibrateServerTime();
    // Re-run the router guard now that both `ready` and `authed` are settled.
    notifyListeners();
  }

  /// Runs [op], retrying on any failure with a short back-off. Right after
  /// sign-in on web the first Firestore calls can fail with permission-denied
  /// until the fresh auth token propagates into the Firestore SDK; retrying a
  /// few times bridges that window so the UI doesn't need a page refresh.
  Future<T?> _retryRead<T>(Future<T> Function() op, {int tries = 6}) async {
    for (var attempt = 0; attempt < tries; attempt++) {
      try {
        return await op();
      } catch (e) {
        if (attempt == tries - 1) {
          debugPrint('hydration read failed after $tries attempts: $e');
          return null;
        }
        await Future<void>.delayed(Duration(milliseconds: 200 + attempt * 250));
      }
    }
    return null;
  }

  /// Forces a fresh ID token into the SDK. Called from stream/write retry
  /// paths after a `permission-denied` — on web the token can lag the auth
  /// state by a few seconds after login, and this pushes a live one through.
  Future<void> _nudgeAuthToken() async {
    try {
      await _repo.currentUser?.getIdToken(true);
    } catch (_) {}
  }

  /// True when [e] looks like the post-login token-propagation denial that a
  /// retry (with a token nudge) can clear, vs a permanent rules rejection.
  bool _isRetriablePermissionError(Object e) =>
      e.toString().contains('permission-denied') ||
      e.toString().contains('PERMISSION_DENIED') ||
      e.toString().contains('unauthenticated');

  /// Loads (creating on first sign-in) the Firestore profile for [fbUser] and
  /// mirrors it into [_user], then subscribes the user-scoped live streams.
  /// Called from the auth-state listener and directly after login/register;
  /// concurrent calls for the same session are coalesced.
  Future<void> _hydrateUser(fa.User fbUser) {
    final inFlight = _hydrating;
    if (inFlight != null) return inFlight;
    final run = _doHydrateUser(fbUser).whenComplete(() => _hydrating = null);
    _hydrating = run;
    return run;
  }

  Future<void> _doHydrateUser(fa.User fbUser) async {
    try {
      // Force a network token refresh so the Firestore SDK is handed a live
      // credential before the first read. A plain getIdToken() can return a
      // stale/empty token right after sign-in on web, which is what made every
      // isMember-gated read fail with permission-denied until a page reload.
      try {
        await fbUser.getIdToken(true);
      } catch (_) {
        try {
          await fbUser.getIdToken();
        } catch (_) {}
      }

      await _retryRead(() => _repo.ensureUserDoc(
            uid: fbUser.uid,
            name: fbUser.displayName ?? 'Player',
            email: fbUser.email ?? '',
            starterPresets: AppProvider.seedPresets,
            starterChipSet: AppProvider.seedChipSet,
          ));
      final loaded = await _retryRead(() => _repo.loadUser(fbUser.uid));
      _user = loaded ??
          _user ?? // never downgrade an already-hydrated profile
          AppUser(
            id: fbUser.uid,
            name: fbUser.displayName ?? 'Player',
            email: fbUser.email ?? '',
            isAdmin: false,
            stats: const UserStats(
              played: 0,
              wins: 0,
              podium: 0,
              avgFinish: 0,
              knockouts: 0,
            ),
          );
      notifyListeners();
      await _loadUserPrefs(fbUser.uid);
      // Subscribe only now — after the retried reads confirm the token works —
      // so the .snapshots() streams don't immediately error out (a Firestore
      // stream that hits permission-denied is dead until re-created).
      _subscribeUserData();
    } catch (e) {
      debugPrint('AppProvider: profile hydration failed: $e');
    }
  }

  /// Restores per-user preferences (`users/{uid}.prefs`) onto local state.
  Future<void> _loadUserPrefs(String uid) async {
    if (!_backendUp) return;
    try {
      final prefs = await _repo.loadUserPrefs(uid);
      final voice = prefs['voiceEnabled'];
      if (voice is bool) _voiceEnabled = voice;
      final showTour = prefs['showAppTour'];
      if (showTour is bool) _showAppTour = showTour;
      final savedPendingCheckIn = prefs['pendingCheckIn'];
      if (savedPendingCheckIn is Map) {
        _pendingCheckIn.addAll(savedPendingCheckIn.cast<String, String>());
      }
      final notify = prefs['browserNotify'];
      if (notify is bool) {
        _notificationsEnabled = notify;
      } else {
        // By default turn on if no preference is set
        _notificationsEnabled = true;
        _persistPref('browserNotify', true);
        // Fire-and-forget the permission request so it prompts the user automatically
        Future.microtask(() => setNotificationsEnabled(true));
      }
      final colorTheme = prefs['colorTheme'];
      if (colorTheme is String) _colorTheme = colorTheme;
      final themePref = prefs['themePreference'];
      if (themePref is String) _themePreference = themePref;
      // Restore per-group notification-mirror cursors so history isn't
      // re-mirrored on every sign-in.
      for (final entry in prefs.entries) {
        if (entry.key.startsWith('notifMirrorCursor_')) {
          final gid = entry.key.substring('notifMirrorCursor_'.length);
          final v = entry.value;
          if (v is num) _mirrorCursors[gid] = v.toInt();
        } else if (entry.key.startsWith('notifMirrorPrimed_')) {
          final gid = entry.key.substring('notifMirrorPrimed_'.length);
          final v = entry.value;
          if (v is bool) _outboxPrimed[gid] = v;
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('loadUserPrefs failed: $e');
    }
  }

  /// Returns `null` on success or a friendly error message for the UI.
  Future<String?> login(String email, String password) async {
    try {
      final cred = await _repo.signIn(email, password);
      if (cred.user != null) await _hydrateUser(cred.user!);
      // Wait (bounded) for groups + the auto-selected group's bundle so the
      // dashboard is populated the moment we navigate to it.
      await userDataReady.timeout(const Duration(seconds: 8), onTimeout: () {});
      return null;
    } on fa.FirebaseAuthException catch (e) {
      return switch (e.code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' =>
          'Incorrect email or password.',
        'invalid-email' => 'Enter a valid email address.',
        'user-disabled' => 'This account has been disabled.',
        'too-many-requests' => 'Too many attempts. Please try again later.',
        'network-request-failed' => 'Network error. Check your connection.',
        _ => e.message ?? 'Sign-in failed. Please try again.',
      };
    }
  }

  /// Returns `null` on success or a friendly error message for the UI.
  Future<String?> register(String name, String email, String password) async {
    try {
      final cred = await _repo.signUp(
        name: name,
        email: email,
        password: password,
      );
      if (cred.user != null) {
        await _hydrateUser(cred.user!);
        // Guarantee the chosen name is stored even if displayName propagation
        // lagged during hydration's ensureUserDoc.
        if (_user != null && _user!.name != name) {
          await _retryRead(
              () => _repo.updateUserProfile(cred.user!.uid, name: name));
          _user = _user!.copyWith(name: name);
          notifyListeners();
        }
      }
      await userDataReady.timeout(const Duration(seconds: 8), onTimeout: () {});
      return null;
    } on fa.FirebaseAuthException catch (e) {
      return switch (e.code) {
        'email-already-in-use' => 'An account already exists for that email.',
        'weak-password' => 'That password is too weak — use at least 8 characters.',
        'invalid-email' => 'Enter a valid email address.',
        'network-request-failed' => 'Network error. Check your connection.',
        _ => e.message ?? 'Registration failed. Please try again.',
      };
    }
  }

  /// Converts the current anonymous guest session into a full account by
  /// linking credentials onto the existing uid, so stats/results recorded as
  /// a guest carry over automatically (user-flow spec §6.7). Returns `null`
  /// on success or a friendly error message for the UI.
  Future<String?> convertGuestAccount(
      String name, String email, String password) async {
    if (!_repo.isSignedInAsGuest) return 'Not a guest session.';
    try {
      final cred = await _repo.linkGuestAccount(
        name: name,
        email: email,
        password: password,
      );
      if (cred.user != null) await _hydrateUser(cred.user!);
      return null;
    } on fa.FirebaseAuthException catch (e) {
      return switch (e.code) {
        'email-already-in-use' ||
        'credential-already-in-use' =>
          'An account already exists for that email.',
        'weak-password' =>
          'That password is too weak — use at least 8 characters.',
        'invalid-email' => 'Enter a valid email address.',
        'network-request-failed' => 'Network error. Check your connection.',
        _ => e.message ?? 'Account creation failed. Please try again.',
      };
    } on StateError {
      return 'Your session expired. Please sign in again.';
    }
  }

  /// Sends the reset email; returns `null` on success or a friendly error.
  Future<String?> requestPasswordReset(String email) async {
    try {
      await _repo.sendPasswordReset(email);
      return null;
    } on fa.FirebaseAuthException catch (e) {
      return switch (e.code) {
        'user-not-found' || 'invalid-credential' =>
          'No account found for that email.',
        'invalid-email' => 'Enter a valid email address.',
        'network-request-failed' => 'Network error. Check your connection.',
        _ => e.message ?? 'Could not send the reset email. Please try again.',
      };
    }
  }

  /// Signs in anonymously — the entry point of the guest flow.
  Future<String?> signInAsGuest() async {
    try {
      final cred = await _repo.signInAsGuest();
      if (cred.user != null) await _hydrateUser(cred.user!);
      return null;
    } on fa.FirebaseAuthException catch (e) {
      return e.message ?? 'Guest sign-in failed. Please try again.';
    }
  }

  /// Triggers Google Sign-In and authenticates with Firebase. Returns `null`
  /// on success, an empty string when the user cancels (caller should no-op),
  /// or a friendly error message on failure.
  Future<String?> loginWithGoogle() async {
    try {
      final cred = await _repo.signInWithGoogle();
      if (cred == null) return ''; // user cancelled — silent abort
      if (cred.user != null) await _hydrateUser(cred.user!);
      await userDataReady.timeout(const Duration(seconds: 8), onTimeout: () {});
      return null;
    } on fa.FirebaseAuthException catch (e) {
      return switch (e.code) {
        'account-exists-with-different-credential' =>
          'An account already exists with this email using a different sign-in method.',
        'invalid-credential' => 'Google sign-in failed. Please try again.',
        'user-disabled' => 'This account has been disabled.',
        'network-request-failed' => 'Network error. Check your connection.',
        _ => e.message ?? 'Google sign-in failed. Please try again.',
      };
    } catch (e) {
      return 'Google sign-in failed. Please try again.';
    }
  }

  /// Upgrades the current anonymous guest session to a Google-linked account.
  /// Returns `null` on success, empty string on cancel, or an error message.
  Future<String?> convertGuestWithGoogle() async {
    if (!_repo.isSignedInAsGuest) return 'Not a guest session.';
    try {
      final cred = await _repo.linkGuestWithGoogle();
      if (cred == null) return ''; // user cancelled
      if (cred.user != null) await _hydrateUser(cred.user!);
      return null;
    } on fa.FirebaseAuthException catch (e) {
      return switch (e.code) {
        'credential-already-in-use' ||
        'email-already-in-use' =>
          'A Google account already exists for this email.',
        'network-request-failed' => 'Network error. Check your connection.',
        _ => e.message ?? 'Google sign-in failed. Please try again.',
      };
    } on StateError {
      return 'Your session expired. Please sign in again.';
    } catch (e) {
      return 'Google sign-in failed. Please try again.';
    }
  }

  Future<void> logout() async {
    // OneSignal external-id detach happens automatically via the auth-state
    // listener in PushService — no stale subscriptions linger on the account.
    await _repo.signOut();
  }

  /// Deletes the signed-in account (profile doc, membership mirrors, auth
  /// user) and invalidates every session so a deleted account cannot keep
  /// using a stale live game (checklist 05-014). Returns a friendly error
  /// message on failure — notably `requires-recent-login`, where the caller
  /// must re-authenticate first.
  Future<String?> deleteAccount() async {
    try {
      await _repo.deleteAccount();
    } on fa.FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return 'For security please sign in again before deleting your account.';
      }
      return e.message ?? 'Could not delete the account. Please try again.';
    }
    _user = null;
    _currentGame = null;
    _cashSession = null;
    _guestSession = null;
    _restoredFromRecovery = false;
    _recoveryTime = null;
    RecoveryService.clearGame();
    RecoveryService.clearCashSession();
    RecoveryService.clearGuestSession();
    notifyListeners();
    return null;
  }

  String get guestCode => _guestCode;

  void setGuestCode(String code) {
    _guestCode = code;
    notifyListeners();
  }
}