import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/alerts/alert_detail_screen.dart';
import '../features/alerts/alerts_screen.dart';
import '../features/citizen/report_form_screen.dart';
import '../features/citizen/reports_screen.dart';
import '../features/consent/consent_screen.dart';
import '../features/dashboards/dashboards_screen.dart';
import '../features/dashboards/indicator_detail_screen.dart';
import '../features/home/home_screen.dart';
import '../features/impact/impact_screen.dart';
import '../features/map/map_screen.dart';
import '../features/settings/methodology_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/thresholds_screen.dart';
import '../features/shell/app_shell.dart';
import '../state/settings_controller.dart';

/// Nomes de rota centralizados: as telas nunca usam caminhos escritos à mão.
class Routes {
  const Routes._();
  static const consent = 'consentimento';
  static const home = 'inicio';
  static const dashboards = 'paineis';
  static const indicator = 'indicador';
  static const alerts = 'alertas';
  static const alertDetail = 'alerta';
  static const map = 'mapa';
  static const reports = 'cidadao';
  static const reportForm = 'novo-relato';
  static const settings = 'ajustes';
  static const thresholds = 'limiares';
  static const methodology = 'metodologia';
  static const impact = 'impacto';
}

GoRouter buildRouter(SettingsController settings) {
  final rootKey = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/inicio',
    refreshListenable: settings,
    redirect: (context, state) {
      final atConsent = state.matchedLocation == '/consentimento';
      if (!settings.onboarded) return atConsent ? null : '/consentimento';
      return atConsent ? '/inicio' : null;
    },
    routes: [
      GoRoute(
        path: '/consentimento',
        name: Routes.consent,
        builder: (_, _) => const ConsentScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/inicio',
              name: Routes.home,
              builder: (_, _) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/paineis',
              name: Routes.dashboards,
              builder: (_, state) => DashboardsScreen(
                initialTab: state.uri.queryParameters['aba'],
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/alertas',
              name: Routes.alerts,
              builder: (_, _) => const AlertsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/mapa',
              name: Routes.map,
              builder: (_, _) => const MapScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/cidadao',
              name: Routes.reports,
              builder: (_, _) => const ReportsScreen(),
            ),
          ]),
        ],
      ),
      // Telas de detalhe ficam sobre o menu, com passagem de parâmetros na rota.
      GoRoute(
        path: '/indicador/:indicatorId',
        name: Routes.indicator,
        parentNavigatorKey: rootKey,
        builder: (_, state) => IndicatorDetailScreen(
          indicatorId: state.pathParameters['indicatorId']!,
        ),
      ),
      GoRoute(
        path: '/alerta/:alertId',
        name: Routes.alertDetail,
        parentNavigatorKey: rootKey,
        builder: (_, state) => AlertDetailScreen(
          alertId: state.pathParameters['alertId']!,
        ),
      ),
      GoRoute(
        path: '/novo-relato',
        name: Routes.reportForm,
        parentNavigatorKey: rootKey,
        builder: (_, _) => const ReportFormScreen(),
      ),
      GoRoute(
        path: '/ajustes',
        name: Routes.settings,
        parentNavigatorKey: rootKey,
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/limiares',
        name: Routes.thresholds,
        parentNavigatorKey: rootKey,
        builder: (_, state) => ThresholdsScreen(
          focusIndicatorId: state.uri.queryParameters['indicador'],
        ),
      ),
      GoRoute(
        path: '/metodologia',
        name: Routes.methodology,
        parentNavigatorKey: rootKey,
        builder: (_, _) => const MethodologyScreen(),
      ),
      GoRoute(
        path: '/impacto',
        name: Routes.impact,
        parentNavigatorKey: rootKey,
        builder: (_, _) => const ImpactScreen(),
      ),
    ],
  );
}
