import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territorio_vivo/core/app_router.dart';
import 'package:territorio_vivo/data/explanation_service.dart';
import 'package:territorio_vivo/data/local_store.dart';
import 'package:territorio_vivo/data/notification_service.dart';
import 'package:territorio_vivo/data/open_meteo_service.dart';
import 'package:territorio_vivo/data/synthetic_data_service.dart';
import 'package:territorio_vivo/data/territory_repository.dart';
import 'package:territorio_vivo/main.dart';
import 'package:territorio_vivo/state/alerts_controller.dart';
import 'package:territorio_vivo/state/reports_controller.dart';
import 'package:territorio_vivo/state/settings_controller.dart';
import 'package:territorio_vivo/state/territory_controller.dart';

/// Monta o app real com a API de clima fora do ar, o que também exercita o
/// estado de erro e a continuidade dos painéis sintéticos.
Future<(GoRouter, AlertsController)> pumpApp(
  WidgetTester tester, {
  bool onboarded = true,
}) async {
  SharedPreferences.setMockInitialValues({
    'flutter.onboarded': onboarded,
    'flutter.consent': onboarded,
  });
  final store = await LocalStore.open();
  final settings = SettingsController(store);
  final territory = TerritoryController(
    repository: TerritoryRepository(
      store: store,
      climate: OpenMeteoService(
        client: MockClient((_) async => http.Response('erro', 500)),
      ),
      synthetic: const SyntheticDataService(latency: Duration.zero),
    ),
    store: store,
  );
  final reports = ReportsController(store);
  final alerts = AlertsController(
    territory: territory,
    settings: settings,
    reports: reports,
    store: store,
    notifications: NotificationService(),
  );
  final router = buildRouter(settings);
  await tester.runAsync(territory.loadAll);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: territory),
        ChangeNotifierProvider.value(value: reports),
        ChangeNotifierProvider.value(value: alerts),
        Provider(create: (_) => ExplanationService()),
      ],
      child: TerritorioVivoApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  return (router, alerts);
}

void useSmallPhone(WidgetTester tester, {double textScale = 1}) {
  tester.view.physicalSize = const Size(360, 720);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  const routes = [
    '/inicio',
    '/paineis',
    '/paineis?aba=clima',
    '/paineis?aba=servicos',
    '/alertas',
    '/cidadao',
    '/novo-relato',
    '/ajustes',
    '/limiares',
    '/metodologia',
    '/impacto',
    '/indicador/agua',
    '/indicador/residuos',
    '/indicador/temperatura',
  ];

  for (final scale in [1.0, 2.0]) {
    testWidgets('telas abrem sem estouro de layout com fonte $scale', (
      tester,
    ) async {
      useSmallPhone(tester, textScale: scale);
      final (router, alerts) = await pumpApp(tester);
      final targets = [
        ...routes,
        for (final alert in alerts.current.take(2)) '/alerta/${alert.id}',
      ];
      for (final route in targets) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: route);
      }
    });
  }

  testWidgets('sem consentimento concluído, o app abre na etapa inicial', (
    tester,
  ) async {
    useSmallPhone(tester);
    await pumpApp(tester, onboarded: false);
    expect(find.text('Como tratamos seus dados'), findsOneWidget);
  });

  testWidgets('clima fora do ar mostra erro e mantém os outros painéis', (
    tester,
  ) async {
    useSmallPhone(tester);
    final (router, _) = await pumpApp(tester);
    router.go('/paineis?aba=clima');
    await tester.pumpAndSettle();
    expect(find.text('Clima indisponível'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('formulário de relato mostra erros e depois salva', (
    tester,
  ) async {
    useSmallPhone(tester);
    final (router, _) = await pumpApp(tester);
    router.go('/cidadao');
    await tester.pumpAndSettle();
    router.pushNamed(Routes.reportForm);
    await tester.pumpAndSettle();

    final submit = find.text('Salvar relato');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Escolha o tipo de ocorrência.'), findsOneWidget);
    expect(find.text('Descreva a ocorrência.'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField),
      'Ligue no telefone (11) 91234-5678 para saber',
    );
    await tester.pump();
    expect(find.textContaining('Remova e-mail'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField),
      'Rua alagada perto da escola depois da chuva',
    );
    await tester.tap(find.text('Tipo de ocorrência'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alagamento').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Rua alagada perto da escola depois da chuva'),
        findsOneWidget);
  });
}
