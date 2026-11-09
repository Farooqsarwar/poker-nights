import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Web implementation of permission-gated browser notifications using the
/// standard Notification API — no FCM/VAPID setup required (spec §10.3/§14.3).
///
/// Uses `package:web` rather than `dart:html`, which is deprecated and is not
/// available at all when compiling to Wasm.
class BrowserNotify {
  BrowserNotify._();

  /// `dart:html` had a `Notification.supported` getter; `package:web` binds the
  /// API unconditionally, so the feature test is an explicit look at the global
  /// object. Safari on iOS below 16.4 is the case that matters — it has no
  /// `Notification` constructor, and touching `permission` there throws.
  static bool get supported => globalContext.has('Notification');

  static bool get granted => supported && web.Notification.permission == 'granted';

  static Future<bool> requestPermission() async {
    if (!supported) return false;
    final result = await web.Notification.requestPermission().toDart;
    return result.toDart == 'granted';
  }

  static void show(String title, String body) {
    if (!supported || !granted) return;
    web.Notification(title, web.NotificationOptions(body: body));
  }
}
