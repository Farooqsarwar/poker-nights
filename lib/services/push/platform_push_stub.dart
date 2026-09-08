import 'platform_push_contract.dart';

/// No-op implementation for platforms without OneSignal support
/// (desktop shells, tests). The in-app inbox keeps working.
class StubPlatformPush implements PlatformPush {
  @override
  bool get isReady => false;

  @override
  bool get permissionGranted => false;

  @override
  Future<void> initialize(
    String appId, {
    void Function(bool granted)? onPermissionChanged,
    void Function(String? deepLink)? onNotificationClick,
  }) async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> setExternalId(String uid) async {}

  @override
  Future<void> clearExternalId() async {}

  @override
  Future<void> optOut() async {}
}

PlatformPush createPlatformPush() => StubPlatformPush();
