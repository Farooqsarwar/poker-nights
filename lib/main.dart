import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'providers/app_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const PokerNightApp(),
    ),
  );
}

/// Root widget — wires the dark casino theme, the app provider, and the router.
class PokerNightApp extends StatelessWidget {
  const PokerNightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Poker Night',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}