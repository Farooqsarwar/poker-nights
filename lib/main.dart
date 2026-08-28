import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'app/colors.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'responsive/responsive.dart';
import 'services/fcm_service.dart';
import 'theme/theme_palette.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Production error handling — show a friendly error overlay instead of a red screen.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 48),
              const SizedBox(height: 12),
              Text(
                kDebugMode
                    ? details.exception.toString()
                    : 'Something went wrong. Please restart the app.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  };

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable Firestore offline persistence (tech spec §4.1 — local recovery).
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (_) {
    // Settings may already be set or Firestore unavailable in tests.
  }

  // Use clean URLs (no #) so deep links like /join-group?code=X work directly.
  if (kIsWeb) usePathUrlStrategy();
  // -- Firebase App Check (tech spec section 22) --
  await _initAppCheck();

  // Initialize Firebase Cloud Messaging for Push Notifications
  try {
    await FCMService().init();
  } catch (e) {
    debugPrint('FCM init failed: $e');
  }

  final appProvider = AppProvider();
  runApp(
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
Future<void> _initAppCheck() async {
  const isDebugMode = bool.fromEnvironment('APP_CHECK_DEBUG');
  const siteKey = String.fromEnvironment('APP_CHECK_RECAPTCHA_SITE_KEY');
  try {
    await FirebaseAppCheck.instance.activate(
      webProvider: isDebugMode
          ? ReCaptchaV3Provider('debug')
          : siteKey.isNotEmpty
              ? ReCaptchaV3Provider(siteKey)
              : ReCaptchaV3Provider('MISSING_SITE_KEY'),
      androidProvider:
          isDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: isDebugMode
          ? AppleProvider.debug
          : AppleProvider.appAttestWithDeviceCheckFallback,
    );
    FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);

    if (isDebugMode) {
      // ignore: avoid_print
      print('[AppCheck] Activated with DEBUG provider -- NOT for production.');
    }
  } catch (e) {
    // ignore: avoid_print
    print('[AppCheck] Activation failed: $e. '
        'Firestore requests will be rejected in enforced mode.');
  }
}

/// Root widget -- wires the casino theme, the app provider, and the router.
class PokerNightApp extends StatelessWidget {
  const PokerNightApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    // Resolve the active palette from the stored color-theme id and push it
    // into AppColors so every static accessor returns the correct value.
    final palette = ThemePalettes.forId(app.colorTheme);
    AppColors.currentPalette = palette;

    return MaterialApp.router(
      key: ValueKey('app-${app.colorTheme}-${app.themePreference}'),
      title: 'Poker Night',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.forPalette(palette, brightness: Brightness.light),
      darkTheme: AppTheme.forPalette(palette, brightness: Brightness.dark),
      themeMode: switch (app.themePreference) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      },
      routerConfig: router,
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
