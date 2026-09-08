import 'dart:async';
import 'dart:html' as html;

/// Web implementation of permission-gated browser notifications using the
/// standard Notification API — no FCM/VAPID setup required (spec §10.3/§14.3).
class BrowserNotify {
  BrowserNotify._();

  static bool get supported => html.Notification.supported;

  static bool get granted =>
      html.Notification.permission.toString().contains('granted');

  static Future<bool> requestPermission() async {
    if (!supported) return false;
    final result = await html.Notification.requestPermission();
    return result.toString().contains('granted');
  }

  static void show(String title, String body) {
    if (!supported || !granted) return;
    html.Notification(title, body: body);
  }
}
