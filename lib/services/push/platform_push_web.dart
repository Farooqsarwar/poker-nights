import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';

import 'platform_push_contract.dart';

/// Web implementation wrapping the OneSignal JavaScript SDK (v16).
///
/// The `onesignal_flutter` plugin has no web implementation, so this class
/// drives `window.OneSignal` through `dart:js_interop`. `web/index.html`
/// loads the SDK script and defines the `OneSignalDeferred` queue; the
/// OneSignal service workers live in `web/onesignal/` (subdirectory scope so
/// they coexist with Flutter's own service worker).
class WebPlatformPush implements PlatformPush {
  bool _granted = false;
  bool _ready = false;

  @override
  bool get isReady => _ready;

  @override
  bool get permissionGranted => _granted;

  /// Runs [action] against the OneSignal SDK object, using the loaded global
  /// when available and the deferred queue otherwise.
  Future<void> _withSdk(Future<void> Function(JSObject one) action) async {
    try {
      if (globalContext.has('OneSignal')) {
        await action(globalContext['OneSignal'] as JSObject);
        return;
      }
      if (!globalContext.has('OneSignalDeferred')) {
        debugPrint('[Push] OneSignal web SDK not loaded — check index.html.');
        return;
      }
      final deferred = globalContext['OneSignalDeferred'] as JSObject;
      final completer = Completer<void>();
      deferred.callMethod(
        'push'.toJS,
        ((JSObject sdk) {
          () async {
            try {
              await action(sdk);
            } catch (e) {
              debugPrint('[Push] web SDK action failed: $e');
            } finally {
              if (!completer.isCompleted) completer.complete();
            }
          }();
        }).toJS,
      );
      await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => debugPrint('[Push] OneSignal web init timed out'),
      );
    } catch (e) {
      debugPrint('[Push] web interop failed: $e');
    }
  }

  @override
  Future<void> initialize(
    String appId, {
    void Function(bool granted)? onPermissionChanged,
    void Function(String? deepLink)? onNotificationClick,
  }) async {
    await _withSdk((one) async {
      final config = <String, Object?>{
        'appId': appId,
        'safari_web_id': 'web.onesignal.auto.13d8bf97-93cf-4a09-b799-2a50baaf1ebd',
        // Subdirectory scope so OneSignal's worker coexists with Flutter's
        // flutter_service_worker.js (PWA caching) at the root scope.
        'serviceWorkerPath': 'onesignal/OneSignalSDKWorker.js',
        'serviceWorkerParam': <String, Object?>{'scope': '/onesignal/'},
      }.jsify();
      try {
        await (one.callMethod('init'.toJS, config) as JSPromise).toDart;
        _ready = true;
      } catch (e) {
        final err = e.toString();
        if (err.contains('already initialized') || err.contains('already been initialized')) {
          _ready = true;
        }
        debugPrint('[Push] web init skipped: $e');
      }
      
      if (!_ready) return; // Stop executing further if SDK is entirely blocked (e.g. localhost)

      _granted = _readPermission(one);

      final notifications = one['Notifications'] as JSObject?;
      try {
        notifications?.callMethod(
          'addEventListener'.toJS,
          'permissionChange'.toJS,
          ((JSAny? granted) {
            _granted = granted.dartify() == true;
            onPermissionChanged?.call(_granted);
          }).toJS,
        );
      } catch (e) {
        debugPrint('[Push] web permissionChange listener failed: $e');
      }
      try {
        notifications?.callMethod(
          'addEventListener'.toJS,
          'click'.toJS,
          ((JSObject event) {
            try {
              final result = event['result'] as JSObject?;
              final url = result?['url'];
              onNotificationClick?.call(url.dartify() as String?);
            } catch (e) {
              debugPrint('[Push] web click handler failed: $e');
            }
          }).toJS,
        );
      } catch (e) {
        debugPrint('[Push] web click listener failed: $e');
      }
      onPermissionChanged?.call(_granted);
    });
  }

  bool _readPermission(JSObject one) {
    try {
      final notifications = one['Notifications'] as JSObject?;
      return notifications?['permission'].dartify() == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      var granted = false;
      await _withSdk((one) async {
        final notifications = one['Notifications'] as JSObject;
        final result =
            await (notifications.callMethod('requestPermission'.toJS) as JSPromise)
                .toDart;
        granted = result.dartify() == true || _readPermission(one);
        _granted = granted;
      });
      return granted;
    } catch (e) {
      debugPrint('[Push] web requestPermission failed: $e');
      return false;
    }
  }

  @override
  Future<void> setExternalId(String uid) async {
    if (!_ready) return;
    await _withSdk((one) async {
      await (one.callMethod('login'.toJS, uid.toJS) as JSPromise).toDart;
      try {
        final user = one['User'] as JSObject;
        await (user.callMethod('addTag'.toJS, 'uid'.toJS, uid.toJS) as JSPromise)
            .toDart;
      } catch (e) {
        debugPrint('[Push] web addTag failed: $e');
      }
    });
  }

  @override
  Future<void> clearExternalId() async {
    await _withSdk((one) async {
      await (one.callMethod('logout'.toJS) as JSPromise).toDart;
    });
  }

  @override
  Future<void> optOut() async {
    await _withSdk((one) async {
      try {
        final user = one['User'] as JSObject;
        final sub = user['pushSubscription'] as JSObject;
        await (sub.callMethod('optOut'.toJS) as JSPromise).toDart;
      } catch (e) {
        debugPrint('[Push] web optOut failed: $e');
      }
    });
  }
}

PlatformPush createPlatformPush() => WebPlatformPush();
