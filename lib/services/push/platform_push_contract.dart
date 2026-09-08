/// Contract implemented by every platform backend of [PushService].
abstract class PlatformPush {
  /// Whether the SDK finished initialising on this platform.
  bool get isReady;

  /// Whether the user granted notification permission.
  bool get permissionGranted;

  /// Initialises OneSignal with [appId] and wires the callbacks.
  Future<void> initialize(
    String appId, {
    void Function(bool granted)? onPermissionChanged,
    void Function(String? deepLink)? onNotificationClick,
  });

  /// Shows the OS permission prompt. Returns whether it was granted.
  Future<bool> requestPermission();

  /// Associates this device's subscription with [uid] (Firebase uid) so the
  /// fan-out can target `include_aliases: {external_id: [uid]}`.
  Future<void> setExternalId(String uid);

  /// Detaches the current user after sign-out.
  Future<void> clearExternalId();

  /// Stops delivering pushes on this device without revoking the OS
  /// permission (used by the settings toggle).
  Future<void> optOut();
}
