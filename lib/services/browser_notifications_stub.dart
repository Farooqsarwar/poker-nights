/// No-op fallback for platforms without the web Notification API
/// (Android/iOS use the in-app inbox only).
class BrowserNotify {
  BrowserNotify._();

  static bool get supported => false;

  static bool get granted => false;

  static Future<bool> requestPermission() async => false;

  static void show(String title, String body) {}
}
