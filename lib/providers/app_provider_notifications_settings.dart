/// AppProvider: Notifications + settings domain mixin.
///
/// Extracted verbatim from app_provider.dart (`// ── Preferences ──`, `// ── Notifications ──`, `// ── Voice & misc ──`, `// ── Account preferences ──`, `// ── Drawer state ──`). Do not change business logic.
part of 'app_provider.dart';

extension AppProviderNotificationsSettings on AppProvider {
  bool get notificationsEnabled => _notificationsEnabled;

  /// Enables push notifications. On Android/iOS this shows the OneSignal
  /// permission prompt; on web it prefers OneSignal web push and falls back
  /// to the plain Notification API when OneSignal isn't loaded. Returns an
  /// error message on denial, null on success.
  Future<String?> setNotificationsEnabled(bool value) async {
    final push = PushService.instance;
    if (value && push.isConfigured) {
      final granted = await push.requestPermission();
      if (!granted) {
        _notificationsEnabled = false;
        _persistPref('browserNotify', false);
        notifyListeners();
        if (kIsWeb) return 'Permission denied in this browser.';
        return 'Permission denied. Enable notifications for Poker Night '
            'in your device settings.';
      }
    } else if (value && kIsWeb && BrowserNotify.supported) {
      // OneSignal not configured — legacy web Notification API fallback.
      final granted = await BrowserNotify.requestPermission();
      if (!granted) {
        _notificationsEnabled = false;
        _persistPref('browserNotify', false);
        notifyListeners();
        return 'Permission denied in this browser.';
      }
    }
    if (!value && push.isConfigured) {
      // Soft-off: stop delivering pushes without revoking the OS permission.
      unawaited(push.optOut().catchError(
          (Object e) => debugPrint('push optOut failed: $e')));
    }
    _notificationsEnabled = value;
    _persistPref('browserNotify', value);
    notifyListeners();
    return null;
  }

  /// Called by [PushService] when the OS/browser permission changes.
  void syncPushPermission(bool granted) {
    if (!granted && _notificationsEnabled) {
      _notificationsEnabled = false;
      _persistPref('browserNotify', false);
      notifyListeners();
    }
  }

  /// Delivers newly-arrived inbox items as browser notifications when the
  /// user opted in; history is never replayed on sign-in. Skipped when
  /// OneSignal web push is live (the service worker already showed the
  /// system notification).
  void _deliverBrowserNotifications(List<AppNotification> list) {
    if (!_notificationsPrimed) {
      _notificationsPrimed = true;
      for (final n in list) {
        _seenNotificationIds.add(n.id);
      }
      return;
    }
    for (final n in list) {
      final isNew = _seenNotificationIds.add(n.id);
      if (isNew &&
          !n.read &&
          _notificationsEnabled &&
          !PushService.instance.suppressesInAppWebBanners) {
        BrowserNotify.show(n.title, n.body);
      }
    }
  }

  List<AppNotification> get notifications => _notifications;

  int get unreadCount => _notifications.where((n) => !n.read).length;

  void markAllRead() {
    _notifications = _notifications.map((n) => n.copyWith(read: true)).toList();
    notifyListeners();
    final uid = _repo.currentUid;
    if (_backendUp && uid != null) {
      unawaited(_repo.markAllNotificationsRead(uid)
          .catchError((Object e) => debugPrint('markAllRead failed: $e')));
    }
  }

  void markNotificationRead(String id) {
    _notifications = _notifications
        .map((n) => n.id == id ? n.copyWith(read: true) : n)
        .toList();
    notifyListeners();
    final uid = _repo.currentUid;
    if (_backendUp && uid != null) {
      unawaited(_repo.markNotificationRead(uid, id)
          .catchError((Object e) => debugPrint('markRead failed: $e')));
    }
  }

  /// Prepends a notification locally, stages it in the current group's outbox
  /// and fans it out to group members as a REAL push via OneSignal — all from
  /// this device, with no Cloud Function (free plan).
  void pushNotification(AppNotification notification) {
    // Collision-safe ids: several call sites build ids from
    // `DateTime.now().millisecondsSinceEpoch` alone, which can collide when
    // notifications are created rapidly (e.g. in a loop). De-duplicate here
    // so the inbox list never holds two identical ids.
    var id = notification.id;
    final existingIds = _notifications.map((n) => n.id).toSet();
    if (existingIds.contains(id)) {
      var n = 2;
      while (existingIds.contains('$id-$n')) {
        n++;
      }
      id = '$id-$n';
      notification = notification.copyWith(id: id);
    }
    _notifications = [notification, ..._notifications];
    // This device originated the event — never re-banner it on itself when
    // the mirrored inbox copy arrives.
    _seenNotificationIds.add(notification.id);
    notifyListeners();
    if (_backendUp) {
      final gid = _currentGroup.id;
      if (gid.isNotEmpty) {
        unawaited(_repo.stageGroupNotification(gid, notification).catchError(
            (Object e) => debugPrint('stageGroupNotification failed: $e')));
        _fanOutPush(gid, notification);
      }
    }
  }

  /// OneSignal fan-out (the free-plan replacement for the Cloud Function).
  /// Only the staging device sends; every other device just mirrors the
  /// outbox into its inbox, so pushes are never duplicated.
  void _fanOutPush(String gid, AppNotification notification) {
    if (!OneSignalSender.instance.configured) return;
    final uid = _repo.currentUid;
    final memberIds = _currentGroup.members.map((m) => m.id).toList();
    final targets = <String>[
      if (notification.audience != null && notification.audience!.isNotEmpty)
        ...notification.audience!.where(memberIds.contains)
      else
        ...memberIds,
    ].where((id) => id != uid).toList();
    if (targets.isEmpty) return;
    unawaited(OneSignalSender.instance
        .send(
          title: notification.title,
          body: notification.body,
          appUrlPath: notification.link,
          externalIds: targets,
        )
        .then((_) => debugPrint('🔥 SUCCESS: Fanned out push to $targets!'))
        .catchError((Object e) => debugPrint('push fan-out failed: $e')));
  }

  bool get voiceEnabled => _voiceEnabled;

  bool get showAppTour => _showAppTour;

  void toggleVoice() {
    _voiceEnabled = !_voiceEnabled;
    _persistPref('voiceEnabled', _voiceEnabled);
    notifyListeners();
  }

  void setAppTour(bool value) {
    if (_showAppTour == value) return;
    _showAppTour = value;
    _persistPref('showAppTour', value);
    notifyListeners();
  }

  void setVoiceEnabled(bool value) {
    if (_voiceEnabled == value) return;
    _voiceEnabled = value;
    _persistPref('voiceEnabled', _voiceEnabled);
    notifyListeners();
  }

  String get thisDeviceId =>
      _thisDeviceId ??= 'dev-${DateTime.now().millisecondsSinceEpoch}';

  String? get audioMasterDeviceId => _audioMasterDeviceId;

  /// Whether announcements may play on this device (no master selected, or
  /// this device is the master) — matches the documented fallback where every
  /// voice-enabled device may announce while no master is chosen.
  bool get thisDeviceIsAudioMaster =>
      _audioMasterDeviceId == null || _audioMasterDeviceId == thisDeviceId;

  /// Selects this device as the Audio Master. Only this device will announce.
  void setAudioMasterDevice() {
    if (_audioMasterDeviceId == thisDeviceId) return;
    _audioMasterDeviceId = thisDeviceId;
    notifyListeners();
  }

  /// Clears the Audio Master selection — every device with voice enabled may
  /// announce again.
  void clearAudioMasterDevice() {
    if (_audioMasterDeviceId == null) return;
    _audioMasterDeviceId = null;
    notifyListeners();
  }

  /// Whether eliminated-player names are announced (checklist 15-053) —
  /// optional per tournament and disabled by default.
  bool get announceEliminations =>
      _currentGame?.settings.announceEliminations ?? false;

  void setAnnounceEliminations(bool value) {
    final game = _currentGame;
    if (game == null || game.settings.announceEliminations == value) return;
    _currentGame = game.copyWith(
      settings: game.settings.copyWith(announceEliminations: value),
    );
    _syncGroupGame();
    notifyListeners();
  }

  bool get soundsEnabled => _soundsEnabled;

  void setSoundsEnabled(bool value) {
    if (_soundsEnabled == value) return;
    _soundsEnabled = value;
    notifyListeners();
  }

  bool get compactSummary => _compactSummary;

  void setCompactSummary(bool value) {
    if (_compactSummary == value) return;
    _compactSummary = value;
    notifyListeners();
  }

  bool get smsEnabled => _smsEnabled;

  void setSmsEnabled(bool value) {
    if (_smsEnabled == value) return;
    _smsEnabled = value;
    notifyListeners();
  }

  String get themePreference => _themePreference;

  void setThemePreference(String value) {
    if (_themePreference == value) return;
    _themePreference = value;
    _persistPref('themePreference', value);
    notifyListeners();
  }

  String get colorTheme => _colorTheme;

  void setColorTheme(String value) {
    if (_colorTheme == value) return;
    _colorTheme = value;
    _persistPref('colorTheme', value);
    notifyListeners();
  }

  String? get defaultChipSetId => _defaultChipSetId;

  void setDefaultChipSet(String? id) {
    if (_defaultChipSetId == id) return;
    _defaultChipSetId = id;
    notifyListeners();
  }

  int get avatarColorIndex => _avatarColorIndex;

  void setAvatarColor(int index) {
    if (_avatarColorIndex == index) return;
    _avatarColorIndex = index;
    notifyListeners();
  }

  bool get isDrawerOpen => _isDrawerOpen;

  void openDrawer() {
    if (_isDrawerOpen) return;
    _isDrawerOpen = true;
    notifyListeners();
  }

  void closeDrawer() {
    if (!_isDrawerOpen) return;
    _isDrawerOpen = false;
    notifyListeners();
  }

  void toggleDrawer() {
    _isDrawerOpen = !_isDrawerOpen;
    notifyListeners();
  }
}
