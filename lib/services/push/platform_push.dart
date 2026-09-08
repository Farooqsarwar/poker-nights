/// Platform abstraction for OneSignal push.
///
/// - Android/iOS (and anything with `dart:io`) → [MobilePlatformPush]
///   (official `onesignal_flutter` plugin).
/// - Web → [WebPlatformPush] (OneSignal JavaScript SDK via interop — the
///   Flutter plugin has no web implementation).
/// - Everything else (desktop, tests) → [StubPlatformPush] no-op.
library;

export 'platform_push_stub.dart'
    if (dart.library.io) 'platform_push_mobile.dart'
    if (dart.library.html) 'platform_push_web.dart';
