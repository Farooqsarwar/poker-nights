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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
