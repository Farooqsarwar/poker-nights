import 'package:flutter/foundation.dart';

/// Where crash reports and analytics events go.
///
/// Nothing here talks to a vendor. Crashlytics and Analytics need native
/// Gradle / Xcode wiring and a consent decision, neither of which can be
/// verified from this codebase alone, so the app reports through this seam and
/// a sink for the chosen SDK is a one-class change (see [Telemetry.install]).
abstract class TelemetrySink {
  void recordError(Object error, StackTrace? stack, {bool fatal = false});

  /// [name] is a fixed snake_case identifier. [params] must never carry names,
  /// emails, chat text, join codes or amounts.
  void logEvent(String name, [Map<String, Object?> params = const {}]);
}

/// The default sink: prints in debug builds, does nothing in release.
class DebugTelemetrySink implements TelemetrySink {
  const DebugTelemetrySink();

  @override
  void recordError(Object error, StackTrace? stack, {bool fatal = false}) {
    if (kDebugMode) debugPrint('telemetry error (fatal=$fatal): $error');
  }

  @override
  void logEvent(String name, [Map<String, Object?> params = const {}]) {
    if (kDebugMode) debugPrint('telemetry event: $name $params');
  }
}

class Telemetry {
  Telemetry._();

  static TelemetrySink _sink = const DebugTelemetrySink();
  static bool _installed = false;

  /// Routes uncaught Flutter and platform errors to [sink]. Safe to call once
  /// at start-up; later calls only swap the sink.
  static void install([TelemetrySink? sink]) {
    if (sink != null) _sink = sink;
    if (_installed) return;
    _installed = true;

    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      _sink.recordError(details.exception, details.stack, fatal: false);
      if (previous != null) {
        previous(details);
      } else {
        FlutterError.presentError(details);
      }
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      _sink.recordError(error, stack, fatal: true);
      // Not handled here: the platform still treats it as uncaught.
      return false;
    };
  }

  static void recordError(Object error, StackTrace? stack) =>
      _sink.recordError(error, stack);

  static void event(String name, [Map<String, Object?> params = const {}]) =>
      _sink.logEvent(name, params);
}
