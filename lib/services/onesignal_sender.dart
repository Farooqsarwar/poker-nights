import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Fans an app event out to group members as REAL push notifications by
/// calling the OneSignal REST API from the originating device.
///
/// This is the free-plan replacement for a Cloud Function fan-out: the sender
/// targets member uids through `include_aliases: {external_id: [...]}` — the
/// same ids devices register with `OneSignal.login(uid)` in [PushService].
///
/// Security note: the REST API key ships inside the app (there is no server).
/// Create a key scoped to **Send messages only** (OneSignal → Settings →
/// Keys & IDs) so a leaked key can only send notifications for your own app
/// and never read user data or change settings.
class OneSignalSender {
  OneSignalSender._();

  static final OneSignalSender instance = OneSignalSender._();

  static const String _appId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: 'e9f508d1-19ef-44ed-aafc-c1578b955715',
  );
  // Scoped to "Send messages only". Ships in the app by design — there is no
  // server. Must be provided at build time with:
  //   --dart-define=ONESIGNAL_REST_API_KEY=...
  // Never hardcode the key in source so it cannot be committed.
  static const String _apiKey = String.fromEnvironment(
    'ONESIGNAL_REST_API_KEY',
  );

  /// OneSignal's newer keys (the `os_v2_app_` prefix) authenticate with the
  /// `Key` scheme; legacy hex keys use `Basic`.
  static String get _authHeader =>
      _apiKey.startsWith('os_v2_') ? 'Key $_apiKey' : 'Basic $_apiKey';

  /// Host this web build is deployed on — used to build the full `url` for
  /// web push click-through. Must match the Site URL configured for the Web
  /// platform in the OneSignal dashboard.
  static const String webOrigin = String.fromEnvironment(
    'ONESIGNAL_WEB_ORIGIN',
    defaultValue: 'https://poker-night-tools.web.app',
  );

  bool get configured => _appId.isNotEmpty && _apiKey.isNotEmpty;

  /// Serialises sends with a small gap so bursts (e.g. one push per seated
  /// player) never trip OneSignal rate limits.
  Future<void> _queue = Future<void>.value();
  Future<void> _enqueue(Future<void> Function() send) {
    final next = _queue.then((_) async {
      await send();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    _queue = next.catchError((Object _) {});
    return next;
  }

  /// Sends one push to [externalIds] (Firebase uids). No-op when the sender
  /// isn't configured or there is nobody to send to.
  Future<void> send({
    required String title,
    required String body,
    String? appUrlPath,
    List<String>? externalIds,
  }) {
    if (!configured || externalIds == null || externalIds.isEmpty) {
      return Future<void>.value();
    }
    return _enqueue(() async {
      final payload = <String, dynamic>{
        'app_id': _appId,
        'target_channel': 'push',
        'name': 'POKER_NIGHT_EVENT',
        'headings': {'en': title},
        'contents': {'en': body},
        'include_aliases': {'external_id': externalIds},
        if (appUrlPath != null && appUrlPath.startsWith('/'))
          'app_url': '$webOrigin$appUrlPath',
      };
      try {
        final resp = await http
            .post(
          Uri.parse('https://api.onesignal.com/notifications'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': _authHeader,
          },
          body: jsonEncode(payload),
        )
            .timeout(const Duration(seconds: 12));
        if (resp.statusCode != 200) {
          final snippet = resp.body.length > 200
              ? resp.body.substring(0, 200)
              : resp.body;
          debugPrint('[PushSender] OneSignal API ${resp.statusCode}: $snippet');
        }
      } catch (e) {
        debugPrint('[PushSender] send failed: $e');
      }
    });
  }
}