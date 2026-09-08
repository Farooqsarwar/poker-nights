import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'platform_push_contract.dart';

/// Android / iOS implementation backed by the official `onesignal_flutter`
/// plugin. All calls are defensive: if the plugin is missing or the SDK
/// rejects the app id, push silently degrades to the in-app inbox.
class MobilePlatformPush implements PlatformPush {
  bool _initialized = false;

  @override
  bool get isReady => _initialized;

  @override
  bool get permissionGranted {
    try {
      return OneSignal.Notifications.permission;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> initialize(
    String appId, {
    void Function(bool granted)? onPermissionChanged,
    void Function(String? deepLink)? onNotificationClick,
  }) async {
    if (_initialized) return;
    try {
      if (kDebugMode) OneSignal.Debug.setLogLevel(OSLogLevel.warn);
      await OneSignal.initialize(appId);
      _initialized = true;

      // Keep the settings toggle in sync when the user changes permission
      // from the system settings.
      OneSignal.Notifications.addPermissionObserver((granted) {
        onPermissionChanged?.call(granted);
      });

      // Tap on a push (foreground, background or cold start) → deep link.
      OneSignal.Notifications.addClickListener((event) {
        final notification = event.notification;
        final route = notification.launchUrl ??
            (notification.additionalData?['app_url'] as String?);
        onNotificationClick?.call(route);
      });
    } catch (e) {
      _initialized = false;
      debugPrint('[Push] mobile init failed: $e');
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!_initialized) return false;
    try {
      return await OneSignal.Notifications.requestPermission(true);
    } catch (e) {
      debugPrint('[Push] requestPermission failed: $e');
      return false;
    }
  }

  @override
  Future<void> setExternalId(String uid) async {
    if (!_initialized) return;
    try {
      await OneSignal.login(uid);
      await OneSignal.User.addTagWithKey('uid', uid);
    } catch (e) {
      debugPrint('[Push] setExternalId failed: $e');
    }
  }

  @override
  Future<void> clearExternalId() async {
    if (!_initialized) return;
    try {
      await OneSignal.User.removeTag('uid');
      await OneSignal.logout();
    } catch (e) {
      debugPrint('[Push] clearExternalId failed: $e');
    }
  }

  @override
  Future<void> optOut() async {
    if (!_initialized) return;
    try {
      await OneSignal.User.pushSubscription.optOut();
    } catch (e) {
      debugPrint('[Push] optOut failed: $e');
    }
  }
}

PlatformPush createPlatformPush() => MobilePlatformPush();
