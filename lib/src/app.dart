import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:kafkalyzer/src/ui/main_layout.dart';
import 'package:kafkalyzer/src/theme.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/services/appearance_settings.dart';

import 'package:kafkalyzer/l10n/app_localizations.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [GoRoute(path: '/', builder: (context, state) => const MainLayout())],
);

class KafkalyzerApp extends StatelessWidget {
  const KafkalyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appearance = getIt<AppearanceSettings>();
    return AnimatedBuilder(
      animation: appearance,
      builder: (context, child) {
        return MaterialApp.router(
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: appearance.themeMode,
          locale: appearance.locale,
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear(
                  mq.textScaler.scale(1) * appearance.textScale,
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          routerConfig: _router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            // Flutter 3.47: flutter_localizations was unbundled into
            // package:material_ui; `delegates` includes Material, Cupertino
            // and Widgets delegates.
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        );
      },
    );
  }
}
