import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kafkalyzer/src/ui/main_layout.dart';
import 'package:kafkalyzer/src/theme.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/theme_controller.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [GoRoute(path: '/', builder: (context, state) => const MainLayout())],
);

class KafkalyzerApp extends StatelessWidget {
  const KafkalyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = getIt<ThemeController>();
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, child) {
        return MaterialApp.router(
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeController.themeMode,
          routerConfig: _router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        );
      },
    );
  }
}
