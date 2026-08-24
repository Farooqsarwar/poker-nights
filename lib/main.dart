import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'responsive/responsive.dart';
import 'services/fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // ── Firebase App Check (tech spec §22) ─────────────────────────────────
  // Protects Firestore and Cloud Functions from non-app clients (bots, scripts,
  // stolen API keys). Providers are selected at compile time via --dart-define:
  //   --dart-define=APP_CHECK_DEBUG=true          → debug provider (dev/CI)
  //   --dart-define=APP_CHECK_RECAPTCHA_SITE_KEY= → web reCAPTCHA v3
  // Android: PlayIntegrity (production), debug token in debug builds.
  // iOS:     AppAttest with DeviceCheck fallback.
  // Web:     reCAPTCHA v3 (site key required in production).
  //
  // IMPORTANT: also enforce App Check in the Firebase Console:
  //   Firebase Console → App Check → Protect resources → Enforce on Firestore
  //   See docs/app_check_setup.md for full setup instructions.
  await _initAppCheck();

  // Initialize Firebase Cloud Messaging for Push Notifications
  try {
    await FCMService().init();
  } catch (e) {
    debugPrint('FCM init failed: $e');
  }

  final appProvider = AppProvider();
  runApp(
    // Initializes flutter_screenutil before any widget reads scaled sizes, so
    // AppScale/AppTypography can adapt fonts to mobile, tablet and laptop.
    ScreenUtilInit(
      designSize: const Size(390, 844),
      splitScreenMode: true,
      minTextAdapt: true,
      builder: (context, child) => ChangeNotifierProvider.value(
        value: appProvider,
        child: PokerNightApp(router: buildAppRouter(appProvider)),
      ),
    ),
  );
}

/// Initialises Firebase App Check with the appropriate provider for the
/// current platform and build mode.
///
/// Build-mode selection (via --dart-define at compile time):
///  - APP_CHECK_DEBUG=true  → use the debug provider (local dev & CI)
///  - APP_CHECK_RECAPTCHA_SITE_KEY=<key> → web reCAPTCHA v3 (production web)
///
/// Failure handling:
///  - In debug builds, a failure is logged but does not block startup.
///  - In release builds, a failure is also logged — Firestore requests will
///    lack an App Check token and will be rejected by enforcement rules.
Future<void> _initAppCheck() async {
  const isDebugMode = bool.fromEnvironment('APP_CHECK_DEBUG');
  const siteKey = String.fromEnvironment('APP_CHECK_RECAPTCHA_SITE_KEY');
  try {
    await FirebaseAppCheck.instance.activate(
      // Web: reCAPTCHA v3 in production; debug token in debug mode.
      webProvider: isDebugMode
          ? ReCaptchaV3Provider('debug')
          : siteKey.isNotEmpty
              ? ReCaptchaV3Provider(siteKey)
              : ReCaptchaV3Provider('MISSING_SITE_KEY'),
      // Android: PlayIntegrity for production, automatic debug in debug builds.
      // PlayIntegrity replaced SafetyNet (deprecated March 2025).
      androidProvider:
          isDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      // iOS: App Attest for production with DeviceCheck fallback;
      // debug token in debug builds.
      appleProvider: isDebugMode
          ? AppleProvider.debug
          : AppleProvider.appAttestWithDeviceCheckFallback,
    );
    FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);

    if (isDebugMode) {
      // ignore: avoid_print
      print('[AppCheck] Activated with DEBUG provider — NOT for production.');
    }
  } catch (e) {
    // ignore: avoid_print
    print('[AppCheck] Activation failed: $e. '
        'Firestore requests will be rejected in enforced mode.');
  }
}

/// Root widget — wires the dark casino theme, the app provider, and the router.
class PokerNightApp extends StatelessWidget {
  const PokerNightApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return MaterialApp.router(
      title: 'Poker Night',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: switch (app.themePreference) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      },
      routerConfig: router,
      // Exposes responsive_framework breakpoints to every screen via
      // ResponsiveBreakpoints.of(context), matching the app's AppBreakpoints.
      builder: (context, child) => ResponsiveBreakpoints.builder(
        child: Builder(
          builder: (innerContext) => ResponsiveScaledBox(
            width: ResponsiveValue<double?>(
              innerContext,
              conditionalValues: [
                const Condition.equals(name: MOBILE, value: 450),
              ],
            ).value,
            child: BouncingScrollWrapper.builder(
              innerContext,
              child ?? const SizedBox.shrink(),
            ),
          ),
        ),
        breakpoints: const [
          Breakpoint(start: 0, end: AppBreakpoints.tablet, name: MOBILE),
          Breakpoint(
            start: AppBreakpoints.tablet,
            end: AppBreakpoints.desktop,
            name: TABLET,
          ),
          Breakpoint(
            start: AppBreakpoints.desktop,
            end: AppBreakpoints.largeDesktop,
            name: DESKTOP,
          ),
          Breakpoint(
            start: AppBreakpoints.largeDesktop,
            end: double.infinity,
            name: 'LARGE_DESKTOP',
          ),
        ],
      ),
    );
  }
}
