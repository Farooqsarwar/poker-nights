import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../app/route_paths.dart';
import '../providers/app_provider.dart';
import 'push/platform_push.dart';
import 'push/platform_push_contract.dart';

/// App-level push orchestration built on OneSignal.
///
/// The free-plan (Spark) replacement for a Cloud Function fan-out:
///  - this device registers itself with OneSignal (external id = Firebase uid),
///  - the device that originates an event fans it out to group members via the
///    OneSignal REST API (see [OneSignalSender]),
///  - taps on pushes are deep-linked through the router, and
///  - the in-app inbox keeps working unchanged.
///
/// Configuration:
///  - `ONESIGNAL_APP_ID`      — the OneSignal App ID (public by design; a
///    default is baked in, override with `--dart-define`).
///  - `ONESIGNAL_REST_API_KEY`— scoped to "send messages" only; ships inside
///    the app because there is no server. Pass with `--dart-define`.
class PushService {
  PushService._();

  static final PushService instance = PushService._();

  static const String appId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: 'e9f508d1-19ef-44ed-aafc-c1578b955715',
  );

  final PlatformPush _platform = createPlatformPush();

  AppProvider? _app;
  GoRouter? _router;
  bool _initialized = false;
  bool _webPushActive = false;
  String? _pendingRoute;

  /// Whether OneSignal was configured at build time.
  bool get isConfigured => appId.isNotEmpty;

  /// Whether the platform SDK has finished loading (web: SDK + init).
  bool get isReady => _platform.isReady;

  /// Whether the OS/browser granted notification permission.
  bool get permissionGranted => _platform.permissionGranted;

  /// True when OneSignal web push is live on this browser — the in-app inbox
  /// mirror must NOT also fire [BrowserNotify] banners (that would double
  /// notify).
  bool get suppressesInAppWebBanners => kIsWeb && _webPushActive;

  /// Attaches the app context and wires OneSignal, auth external-id sync,
  /// permission observers and deep-link routing. Safe to call once.
  Future<void> initialize(AppProvider app, GoRouter router) async {
    _app = app;
    _router = router;
    if (_initialized) return;
    _initialized = true;

    if (!isConfigured) {
      debugPrint('[Push] OneSignal App ID not provided — push disabled.');
      return;
    }

    try {
      await _platform.initialize(
        appId,
        onPermissionChanged: (granted) {
          _webPushActive = kIsWeb && granted;
          app.syncPushPermission(granted);
        },
        onNotificationClick: _handleNotificationClick,
      );
    } catch (e) {
      debugPrint('[Push] init failed: $e');
    }

    // Register the restored session (e.g. app reopened from a push).
    final current = fa.FirebaseAuth.instance.currentUser;
    if (current != null) {
      unawaited(_platform.setExternalId(current.uid));
    }

    fa.FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        unawaited(_platform.setExternalId(user.uid));
      } else {
        unawaited(_platform.clearExternalId());
      }
      _flushPendingRoute();
    });

    // Report the initial permission state so the settings toggle is truthful.
    app.syncPushPermission(_platform.permissionGranted);
  }

  /// Shows the platform permission prompt. Returns whether it was granted.
  Future<bool> requestPermission() => _platform.requestPermission();

  /// Stops pushes on this device (settings toggle off).
  Future<void> optOut() => _platform.optOut();

  /// Routes a push tap. `url` is either `app_url` (`/invitation`-style) or a
  /// full web URL (`https://host/invitation`).
  void _handleNotificationClick(String? url) {
    if (url == null || url.isEmpty) return;
    var path = url;
    if (url.startsWith('http')) {
      path = Uri.tryParse(url)?.path ?? RoutePaths.home;
    }
    if (!path.startsWith('/')) path = '/$path';
    final app = _app;
    final router = _router;
    if (app != null && router != null && app.authReady && app.isAuthenticated) {
      router.go(path);
    } else {
      // Cold start or sign-in not resolved yet — replay once auth is ready.
      _pendingRoute = path;
      _flushPendingRoute();
    }
  }

  void _flushPendingRoute() {
    final app = _app;
    final router = _router;
    final route = _pendingRoute;
    if (app == null || router == null || route == null) return;
    if (!app.authReady || !app.isAuthenticated) return;
    _pendingRoute = null;
    // Give the shell a frame to mount before navigating.
    Future.microtask(() {
      try {
        router.go(route);
      } catch (e) {
        debugPrint('[Push] pending route navigation failed: $e');
      }
    });
  }
}
