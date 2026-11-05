import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/app_router.dart';
import 'core/app_theme.dart';
import 'data/explanation_service.dart';
import 'data/local_store.dart';
import 'data/notification_service.dart';
import 'data/open_meteo_service.dart';
import 'data/synthetic_data_service.dart';
import 'data/territory_repository.dart';
import 'state/alerts_controller.dart';
import 'state/reports_controller.dart';
import 'state/settings_controller.dart';
import 'state/territory_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await LocalStore.open();
  final notifications = NotificationService();

  final settings = SettingsController(store);
  final repository = TerritoryRepository(
    store: store,
    climate: OpenMeteoService(),
    synthetic: const SyntheticDataService(),
  )..simulateOffline = settings.simulateOffline;
  final territory = TerritoryController(repository: repository, store: store);
  final reports = ReportsController(store);
  final alerts = AlertsController(
    territory: territory,
    settings: settings,
    reports: reports,
    store: store,
    notifications: notifications,
  );

  territory.loadAll();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: territory),
        ChangeNotifierProvider.value(value: reports),
        ChangeNotifierProvider.value(value: alerts),
        Provider(create: (_) => ExplanationService()),
      ],
      child: TerritorioVivoApp(router: buildRouter(settings)),
    ),
  );
  notifications.init();
}

class TerritorioVivoApp extends StatelessWidget {
  const TerritorioVivoApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    final choice = context.select<SettingsController, AppThemeChoice>(
      (s) => s.theme,
    );
    final contrast = choice == AppThemeChoice.highContrast;
    return MaterialApp.router(
      title: 'Território Vivo',
      debugShowCheckedModeBanner: false,
      theme: contrast ? AppTheme.highContrast : AppTheme.light,
      darkTheme: contrast ? AppTheme.highContrast : AppTheme.dark,
      highContrastTheme: AppTheme.highContrast,
      highContrastDarkTheme: AppTheme.highContrast,
      themeMode: switch (choice) {
        AppThemeChoice.light => ThemeMode.light,
        AppThemeChoice.dark => ThemeMode.dark,
        AppThemeChoice.highContrast => ThemeMode.dark,
        AppThemeChoice.system => ThemeMode.system,
      },
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
