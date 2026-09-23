import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// Cache buster: 2026-09-02T16:59:49

// Local-development switches. Enable the Firestore + Auth emulators with:
//   flutter run --dart-define=USE_EMULATOR=true
// For testing from a second device on the same Wi-Fi, also point emulator
// traffic at this machine's LAN IP:
//   flutter run --dart-define=USE_EMULATOR=true --dart-define=EMULATOR_HOST=192.168.x.x
// Everything is OFF by default so production builds are unaffected.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:localstore/localstore.dart';

import 'app/colors.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'repositories/firebase_repository.dart';
import 'responsive/responsive.dart';
import 'services/push_service.dart';
import 'theme/theme_palette.dart';
import 'constants/app_constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const useEmulator = bool.fromEnvironment('USE_EMULATOR');
  const emulatorHost = String.fromEnvironment(
    'EMULATOR_HOST',
    defaultValue: 'localhost',
  );
  const emulatorApiPort = int.fromEnvironment(
    'EMULATOR_API_PORT',
    defaultValue: 8080,
  );
  const emulatorAuthPort = int.fromEnvironment(
    'EMULATOR_AUTH_PORT',
    defaultValue: 9099,
  );

  // Production error handling — show a friendly error overlay instead of a red screen.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF131315),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFFACC15),
                size: 48,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                kDebugMode
                    ? details.exception.toString()
                    : 'Something went wrong. Please restart the app.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xB3FFFFFF)),
              ),
            ],
          ),
        ),
      ),
    );
  };

  // Every await between here and runApp() is a chance to never reach runApp()
  // at all — and a main() that never calls runApp() leaves the user staring at
  // a blank page with no error, because ErrorWidget.builder above only catches
  // failures INSIDE a widget tree that exists. A hung Firebase handshake on a
  // captive-portal Wi-Fi is enough to do it.
  //
  // So every startup step is now bounded. A step that times out degrades the
  // feature it belongs to; it no longer takes the whole app down with it. The
  // budgets are generous — this is a backstop against hanging, not a
  // performance tuning knob.
  await _boot(
    'Firebase',
    () => Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ),
    const Duration(seconds: 15),
  );

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

  // Local development against the Firebase emulators (zero production quota).
  // Enabled only via --dart-define=USE_EMULATOR=true. The Firestore + Auth
  // emulators accept requests without App Check, so nothing else is needed.
  if (useEmulator) {
    // ignore: avoid_print
    print('[Emulator] Firestore + Auth -> $emulatorHost');
    FirebaseFirestore.instance.useFirestoreEmulator(
      emulatorHost,
      emulatorApiPort,
    );
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, emulatorAuthPort);
  }
  // -- Firebase App Check (tech spec section 22) --
  if (useEmulator) {
    // ignore: avoid_print
    print('[AppCheck] Skipped -- local emulator mode.');
  } else {
    await _boot('AppCheck', _initAppCheck, const Duration(seconds: 10));
  }

  // Initialize Google Sign-In singleton (must happen before signInWithGoogle).
  await _boot(
    'GoogleSignIn',
    FirebaseRepository.initGoogleSignIn,
    const Duration(seconds: 10),
  );

  // Restore the persisted per-install device id before any Firestore write so
  // echo-prevention and the single-active-editor claim stay stable across
  // restarts.
  await _boot(
    'DeviceId',
    FirebaseRepository.instance.initDeviceId,
    const Duration(seconds: 10),
  );

  // Read the locally cached theme preference before booting the app so the
  // splash screen doesn't jitter while waiting for Firebase.
  String? cachedColorTheme;
  String? cachedThemePref;
  await _boot('ThemeCache', () async {
    final db = Localstore.instance;
    final prefs = await db.collection('app').doc('prefs').get();
    if (prefs != null) {
      cachedColorTheme = prefs['colorTheme'] as String?;
      cachedThemePref = prefs['themePreference'] as String?;
    }
  }, const Duration(seconds: 5));

  // Construction is the last place a blank page can still be produced. The
  // timeouts above stop a startup step from hanging, but AppProvider and the
  // router are built synchronously and can THROW — and a throw here is worse
  // than a hang, because ErrorWidget.builder only replaces a widget that
  // failed inside a tree that exists. Before runApp() there is no tree, so the
  // exception escapes to the browser console and the user is left looking at
  // the same white page with no indication anything went wrong.
  //
  // Showing something is always better than showing nothing, so a failure here
  // renders a real screen that says so.
  late final AppProvider appProvider;
  late final GoRouter router;
  try {
    appProvider = AppProvider(
      initialColorTheme: cachedColorTheme,
      initialThemePreference: cachedThemePref,
    );
    router = buildAppRouter(appProvider);
  } catch (e, stack) {
    // ignore: avoid_print
    print('[Boot] fatal during app construction: $e\n$stack');
    runApp(_BootFailureApp(error: e));
    return;
  }

  // Initialize OneSignal push notifications (Android / iOS / Web). Free-plan
  // replacement for a Cloud Function fan-out — see services/push_service.dart
  // and services/onesignal_sender.dart.
  await _boot(
    'Push',
    () => PushService.instance.initialize(appProvider, router),
    const Duration(seconds: 12),
  );

  runApp(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      splitScreenMode: true,
      minTextAdapt: true,
      builder: (context, child) => ChangeNotifierProvider.value(
        value: appProvider,
        child: PokerNightApp(router: router),
      ),
    ),
  );
}

/// Last-resort screen for a startup that could not build the app at all.
///
/// Deliberately depends on nothing but Flutter itself — no theme, no palette,
/// no provider, no router. Whatever broke during construction must not be able
/// to break the screen that reports it.
class _BootFailureApp extends StatelessWidget {
  const _BootFailureApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFFACC15),
                  size: 48,
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  "Poker Night couldn't start",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  kDebugMode
                      ? error.toString()
                      : 'Please close the tab and open the link again.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xB3FFFFFF)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Runs one startup step so that it can fail or hang without preventing
/// [runApp] from ever being called.
///
/// A startup step gets three outcomes instead of two: it succeeds, it throws,
/// or it never answers. The third is the dangerous one — an unawaited-forever
/// future produces no exception, no log and no frame, so the app looks like it
/// crashed when in fact it is still politely waiting. Bounding each step turns
/// that silent hang into a named, logged degradation.
///
/// [label] appears in the log line so a timeout in the wild names its own
/// culprit rather than requiring a bisect.
Future<void> _boot(
  String label,
  Future<void> Function() step,
  Duration budget,
) async {
  try {
    await step().timeout(budget);
  } on TimeoutException {
    // ignore: avoid_print
    print('[Boot] $label timed out after ${budget.inSeconds}s — continuing.');
  } catch (e) {
    // ignore: avoid_print
    print('[Boot] $label failed: $e — continuing.');
  }
}

/// Initialises Firebase App Check with the appropriate provider for the
/// current platform and build mode.
Future<void> _initAppCheck() async {
  const isDebugMode = bool.fromEnvironment('APP_CHECK_DEBUG');
  const siteKey = String.fromEnvironment('APP_CHECK_RECAPTCHA_SITE_KEY');

  // On Flutter WEB the ReCaptchaV3Provider requires a REAL reCAPTCHA
  // Enterprise site key — there is no "debug" web provider (unlike
  // Android/iOS, where AndroidProvider.debug / AppleProvider.debug emit debug
  // tokens without a site key). Passing a fake/absent key makes the browser
  // try to load ReCAPTCHA and fail with appCheck/recaptcha-error, which blocks
  // google sign-in and Firestore locally.
  //
  // So on web we skip activating App Check in DEBUG builds AND whenever no real
  // site key is supplied. This project does not enforce App Check, so skipping
  // is non-blocking; web keeps App Check only when a genuine reCAPTCHA
  // Enterprise site key is provided via --dart-define.
  if (kIsWeb && (kDebugMode || siteKey.isEmpty)) {
    // ignore: avoid_print
    print('[AppCheck] Skipped on web (debug or no site key) -- not enforced.');
    return;
  }

  try {
    await FirebaseAppCheck.instance.activate(
      webProvider: siteKey.isNotEmpty
          ? ReCaptchaV3Provider(siteKey)
          : ReCaptchaV3Provider('MISSING_SITE_KEY'),
      androidProvider: isDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
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
    print(
      '[AppCheck] Activation failed: $e. '
      'Firestore requests will be rejected in enforced mode.',
    );
  }
}

/// Root widget -- wires the casino theme, the app provider, and the router.
class PokerNightApp extends StatelessWidget {
  const PokerNightApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    // Only rebuild the app shell when the theme actually changes — NOT on every
    // AppProvider.notifyListeners() (clock tick + every Firestore snapshot),
    // which otherwise rebuilds the entire widget tree once per second and can
    // disrupt an in-progress button press.
    final (colorTheme, themePreference) = context
        .select<AppProvider, (String, String)>(
          (a) => (a.colorTheme, a.themePreference),
        );

    // Resolve the active palette from the stored color-theme id and push it
    // into AppColors so every static accessor returns the correct value.
    final palette = ThemePalettes.forId(colorTheme);
    AppColors.currentPalette = palette;

    return MaterialApp.router(
      title: 'Poker Night',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.forPalette(palette, brightness: Brightness.light),
      darkTheme: AppTheme.forPalette(palette, brightness: Brightness.dark),
      themeMode: switch (themePreference) {
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
