import 'package:flutter_test/flutter_test.dart';
import 'package:territorio_vivo/data/open_meteo_service.dart';
import 'package:territorio_vivo/data/synthetic_data_service.dart';
import 'package:territorio_vivo/domain/alert_engine.dart';
import 'package:territorio_vivo/domain/catalog.dart';
import 'package:territorio_vivo/domain/forecasting.dart';
import 'package:territorio_vivo/domain/models.dart';
import 'package:territorio_vivo/domain/validators.dart';

final DateTime now = DateTime(2026, 11, 5, 12);

IndicatorSeries seriesOf(
  String id,
  double Function(int) value, {
  int days = 40,
  int ageDays = 1,
}) {
  final today = DateTime(now.year, now.month, now.day);
  return IndicatorSeries(
    indicatorId: id,
    fetchedAt: now,
    history: [
      for (var i = days - 1; i >= 0; i--)
        DataPoint(
          today.subtract(Duration(days: i + ageDays)),
          value(days - 1 - i),
        ),
    ],
  );
}

TerritorySnapshot snapshotOf(List<IndicatorSeries> series) => TerritorySnapshot(
      territoryId: 'se',
      climateFromCache: false,
      climateUnavailable: false,
      series: {for (final s in series) s.indicatorId: s},
    );

List<TerritoryAlert> run(
  List<IndicatorSeries> series, {
  List<CitizenReport> reports = const [],
}) =>
    const AlertEngine().generate(
      snapshot: snapshotOf(series),
      thresholds: defaultThresholds(),
      reports: reports,
      now: now,
    );

void main() {
  group('Forecaster', () {
    test('acompanha uma tendência linear com erro baixo', () {
      final forecast = const Forecaster().forecast(
        seriesOf('agua', (i) => 100 + i.toDouble()),
        now,
      );
      expect(forecast.trend, TrendDirection.rising);
      expect(forecast.points, hasLength(7));
      expect(forecast.points.first.value, closeTo(140, 0.5));
      expect(forecast.mape, lessThan(0.01));
      expect(forecast.isReliable, isTrue);
      expect(ConfidenceLevel.fromScore(forecast.baseConfidence),
          ConfidenceLevel.alta);
    });

    test('histórico curto torna a previsão não confiável', () {
      final forecast = const Forecaster().forecast(
        seriesOf('agua', (i) => 100, days: 7),
        now,
      );
      expect(forecast.isReliable, isFalse);
      expect(forecast.unreliableReasons.single, contains('Histórico curto'));
      expect(forecast.baseConfidence, lessThanOrEqualTo(0.4));
    });

    test('dados antigos tornam a previsão não confiável', () {
      final forecast = const Forecaster().forecast(
        seriesOf('agua', (i) => 100, ageDays: 6),
        now,
      );
      expect(forecast.isReliable, isFalse);
      expect(forecast.unreliableReasons.single, contains('desatualizados'));
    });

    test('a confiança cai conforme o horizonte aumenta', () {
      final forecast = const Forecaster().forecast(
        seriesOf('agua', (i) => 100 + i.toDouble()),
        now,
      );
      expect(forecast.confidenceAt(7), lessThan(forecast.confidenceAt(1)));
    });
  });

  group('AlertEngine', () {
    test('não gera alerta dentro dos limiares', () {
      expect(run([seriesOf('agua', (i) => 150)]), isEmpty);
    });

    test('alerta de previsão traz evidência, confiança e limitações', () {
      // Sobe até 171 hoje e cruza o limiar de 175 em poucos dias.
      final alerts = run([seriesOf('agua', (i) => 132 + i.toDouble())]);
      final alert = alerts.firstWhere((a) => a.kind == AlertKind.previsao);
      expect(alert.leadDays, inInclusiveRange(1, 7));
      expect(alert.evidence, isNotEmpty);
      expect(alert.limitations, isNotEmpty);
      expect(alert.confidence, inInclusiveRange(0.05, 0.95));
      expect(alert.humanAction, isNotEmpty);
    });

    test('valor além do limiar gera alerta crítico com dados confiáveis', () {
      final alerts = run([seriesOf('agua', (i) => 230)]);
      final alert = alerts.firstWhere((a) => a.kind == AlertKind.observado);
      expect(alert.severity, AlertSeverity.critico);
      expect(alert.leadDays, 0);
    });

    test('dados frágeis nunca chegam ao nível crítico', () {
      final alerts = run([seriesOf('agua', (i) => 230, days: 7)]);
      final alert = alerts.firstWhere((a) => a.kind == AlertKind.observado);
      expect(alert.reliable, isFalse);
      expect(alert.severity, AlertSeverity.atencao);
      expect(alert.confidence, lessThanOrEqualTo(0.4));
    });

    test('indicador de risco por baixa alerta abaixo do limiar', () {
      final alerts = run([seriesOf('reservatorio', (i) => 20)]);
      expect(alerts.first.kind, AlertKind.observado);
      expect(run([seriesOf('reservatorio', (i) => 70)]), isEmpty);
    });

    test('pico isolado gera alerta de anomalia', () {
      final alerts = run([
        seriesOf('energia', (i) => i == 39 ? 6.0 : 4.0 + (i % 2) * 0.1),
      ]);
      expect(alerts.any((a) => a.kind == AlertKind.anomalia), isTrue);
    });

    test('relatos recorrentes geram alerta somente a partir de 3', () {
      CitizenReport report(int n) => CitizenReport(
            id: '$n',
            territoryId: 'se',
            category: ReportCategory.alagamento,
            description: 'Rua alagada perto da praça',
            urgency: 3,
            day: DateTime(2026, 11, 4),
          );
      expect(run(const [], reports: [report(1), report(2)]), isEmpty);
      final alerts = run(const [], reports: [report(1), report(2), report(3)]);
      expect(alerts.single.kind, AlertKind.cidadao);
      expect(alerts.single.reliable, isFalse);
    });

    test('alertas críticos vêm primeiro', () {
      final alerts = run([
        seriesOf('agua', (i) => 230),
        seriesOf('energia', (i) => 6.6),
      ]);
      expect(alerts.first.severity, AlertSeverity.critico);
    });
  });

  group('Validators', () {
    test('recusa relato vazio, curto e com dados pessoais', () {
      expect(Validators.reportDescription(''), isNotNull);
      expect(Validators.reportDescription('curto'), isNotNull);
      for (final text in [
        'Falar com ana@exemplo.com sobre o vazamento',
        'Meu telefone é (11) 91234-5678 para contato',
        'Meu CPF é 123.456.789-09 para registrar',
      ]) {
        expect(Validators.reportDescription(text), contains('Remova'));
      }
      expect(
        Validators.reportDescription('Vazamento grande na esquina da escola'),
        isNull,
      );
    });

    test('limiar aceita vírgula e respeita a faixa permitida', () {
      final water = indicatorById('energia');
      expect(Validators.threshold('6,5', water), isNull);
      expect(Validators.threshold('', water), isNotNull);
      expect(Validators.threshold('abc', water), contains('números'));
      expect(Validators.threshold('999', water), contains('entre'));
    });
  });

  group('Fontes de dados', () {
    test('dados sintéticos são determinísticos', () {
      final territory = kTerritories.first;
      const service = SyntheticDataService(latency: Duration.zero);
      final a = service.generate(territory, now);
      final b = service.generate(territory, now);
      expect(a.first.history.last.value, b.first.history.last.value);
      expect(a.first.history, hasLength(60));
    });

    test('resposta da Open-Meteo separa histórico e previsão', () {
      final series = OpenMeteoService.parseWeather({
        'daily': {
          'time': ['2026-11-03', '2026-11-04', '2026-11-05', '2026-11-06'],
          'temperature_2m_max': [29.2, 32.4, 28.0, null],
          'precipitation_sum': [0.0, 2.3, 8.8, 2.8],
        },
      }, now);
      final temperature = series.first;
      expect(temperature.history, hasLength(2));
      expect(temperature.externalForecast, hasLength(1));
    });

    test('qualidade do ar é agregada por dia', () {
      final series = OpenMeteoService.parseAirQuality({
        'hourly': {
          'time': ['2026-11-04T00:00', '2026-11-04T01:00', '2026-11-05T00:00'],
          'us_aqi': [40, 60, null],
        },
      }, now);
      expect(series.history.single.value, 50);
      expect(series.externalForecast, isEmpty);
    });
  });
}
