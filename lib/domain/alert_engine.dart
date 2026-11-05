import 'dart:math';

import 'catalog.dart';
import 'forecasting.dart';
import 'formatters.dart';
import 'models.dart';

/// Gera alertas a partir de dados e limiares. É uma função pura: mesma entrada,
/// mesma saída. O motor apenas sinaliza; nenhuma ação é executada pelo app.
class AlertEngine {
  const AlertEngine({this.forecaster = const Forecaster()});

  final Forecaster forecaster;

  static const double criticalExcess = 0.15;
  static const double attentionExcess = 0.05;
  static const double anomalyZScore = 2.5;
  static const int clusterMinReports = 3;

  List<TerritoryAlert> generate({
    required TerritorySnapshot snapshot,
    required Map<String, double> thresholds,
    required List<CitizenReport> reports,
    required DateTime now,
  }) {
    final alerts = <TerritoryAlert>[];
    for (final definition in kIndicators) {
      final series = snapshot.series[definition.id];
      if (series == null || series.history.isEmpty) continue;
      final threshold = thresholds[definition.id] ?? definition.defaultThreshold;
      final forecast = forecaster.forecast(series, now);

      final thresholdAlert = _thresholdAlert(
        snapshot.territoryId,
        definition,
        series,
        forecast,
        threshold,
      );
      if (thresholdAlert != null) alerts.add(thresholdAlert);

      if (definition.detectAnomaly) {
        final anomaly = _anomalyAlert(
          snapshot.territoryId,
          definition,
          series,
          forecast,
        );
        if (anomaly != null) alerts.add(anomaly);
      }
    }
    alerts.addAll(_citizenAlerts(snapshot.territoryId, reports, now));
    alerts.sort(compareAlerts);
    return alerts;
  }

  static int compareAlerts(TerritoryAlert a, TerritoryAlert b) {
    final severity = b.severity.index.compareTo(a.severity.index);
    if (severity != 0) return severity;
    return b.confidence.compareTo(a.confidence);
  }

  /// Severidade pelo excesso relativo. Sem confiabilidade, nunca é crítica:
  /// um dado frágil não deve disparar o nível mais alto de urgência.
  static AlertSeverity severityFor(double excess, {required bool reliable}) {
    if (excess >= criticalExcess) {
      return reliable ? AlertSeverity.critico : AlertSeverity.atencao;
    }
    if (excess >= attentionExcess) return AlertSeverity.atencao;
    return AlertSeverity.informativo;
  }

  TerritoryAlert? _thresholdAlert(
    String territoryId,
    IndicatorDefinition d,
    IndicatorSeries series,
    Forecast forecast,
    double threshold,
  ) {
    final latest = series.history.last;
    final territory = territoryById(territoryId).name;
    final reliable = forecast.isReliable;

    if (d.breaches(latest.value, threshold)) {
      final excess = _excess(latest.value, threshold);
      final confidence = reliable ? 0.9 : min(forecast.baseConfidence, 0.4);
      return TerritoryAlert(
        id: _id(territoryId, d.id, AlertKind.observado, latest.date),
        territoryId: territoryId,
        indicatorId: d.id,
        kind: AlertKind.observado,
        severity: severityFor(excess, reliable: reliable),
        title: '${d.name} além do limiar em $territory',
        summary: 'O valor de ${formatDay(latest.date)} já está '
            '${_side(d)} do limiar configurado.',
        evidence: [
          'Último valor: ${formatValue(latest.value, d)} '
              '(${formatDay(latest.date)}).',
          'Limiar configurado: ${formatValue(threshold, d)}.',
          'Diferença para o limiar: ${formatPercent(excess)}.',
          'Tendência dos últimos ${forecast.trainingDays} dias: '
              '${forecast.trend.label}.',
        ],
        confidence: confidence,
        limitations: _limitations(d, forecast),
        humanAction: d.humanAction,
        leadDays: 0,
        reliable: reliable,
        date: latest.date,
      );
    }

    for (var i = 0; i < forecast.points.length; i++) {
      final point = forecast.points[i];
      if (!d.breaches(point.value, threshold)) continue;
      final lead = i + 1;
      final excess = _excess(point.value, threshold);
      return TerritoryAlert(
        id: _id(territoryId, d.id, AlertKind.previsao, point.date),
        territoryId: territoryId,
        indicatorId: d.id,
        kind: AlertKind.previsao,
        severity: severityFor(excess, reliable: reliable),
        title: '${d.name} pode passar do limiar em $territory',
        summary: 'A previsão indica que o limiar pode ser cruzado em '
            '${formatDay(point.date)}, daqui a $lead '
            '${lead == 1 ? 'dia' : 'dias'}.',
        evidence: [
          'Valor previsto para ${formatDay(point.date)}: '
              '${formatValue(point.value, d)}.',
          'Faixa provável: ${formatValue(point.lower, d)} a '
              '${formatValue(point.upper, d)}.',
          'Limiar configurado: ${formatValue(threshold, d)}.',
          'Valor atual: ${formatValue(latest.value, d)}; tendência '
              '${forecast.trend.label}.',
          'Método: ${forecast.method}.',
          if (forecast.mape != null)
            'Erro médio no teste com dados passados: '
                '${formatPercent(forecast.mape!)}.',
        ],
        confidence: forecast.confidenceAt(lead),
        limitations: _limitations(d, forecast),
        humanAction: d.humanAction,
        leadDays: lead,
        reliable: reliable,
        date: point.date,
      );
    }
    return null;
  }

  TerritoryAlert? _anomalyAlert(
    String territoryId,
    IndicatorDefinition d,
    IndicatorSeries series,
    Forecast forecast,
  ) {
    final history = series.history;
    if (history.length < Forecaster.minTrainingDays + 1) return null;
    final latest = history.last;
    final start = max(0, history.length - 1 - forecaster.windowDays);
    final baseline = history
        .sublist(start, history.length - 1)
        .map((e) => e.value)
        .toList();
    final mean = baseline.reduce((a, b) => a + b) / baseline.length;
    final variance = baseline.fold<double>(
          0,
          (acc, v) => acc + pow(v - mean, 2),
        ) /
        (baseline.length - 1);
    final std = sqrt(variance);
    if (std < 1e-6) return null;
    final z = (latest.value - mean) / std;
    if (z.abs() < anomalyZScore) return null;

    return TerritoryAlert(
      id: _id(territoryId, d.id, AlertKind.anomalia, latest.date),
      territoryId: territoryId,
      indicatorId: d.id,
      kind: AlertKind.anomalia,
      severity: AlertSeverity.atencao,
      title: 'Valor incomum de ${d.name.toLowerCase()} em '
          '${territoryById(territoryId).name}',
      summary: 'O valor de ${formatDay(latest.date)} foge do padrão recente '
          'do bairro.',
      evidence: [
        'Último valor: ${formatValue(latest.value, d)}.',
        'Média dos ${baseline.length} dias anteriores: '
            '${formatValue(mean, d)}.',
        'Distância da média: ${z.abs().toStringAsFixed(1).replaceAll('.', ',')} '
            'desvios-padrão (o alerta começa em 2,5).',
      ],
      confidence: forecast.isReliable ? 0.6 : 0.35,
      limitations: [
        'Uma anomalia pode ser erro nos dados, e não um problema real.',
        ..._limitations(d, forecast),
      ],
      humanAction: 'Conferir o dado na fonte antes de qualquer '
          'encaminhamento. ${d.humanAction}',
      leadDays: 0,
      reliable: forecast.isReliable,
      date: latest.date,
    );
  }

  List<TerritoryAlert> _citizenAlerts(
    String territoryId,
    List<CitizenReport> reports,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final recent = reports.where((r) =>
        r.territoryId == territoryId &&
        today.difference(r.day).inDays <= 7);
    final byCategory = <ReportCategory, List<CitizenReport>>{};
    for (final report in recent) {
      byCategory.putIfAbsent(report.category, () => []).add(report);
    }

    final alerts = <TerritoryAlert>[];
    byCategory.forEach((category, items) {
      if (items.length < clusterMinReports) return;
      final highUrgency = items.where((r) => r.urgency == 3).length;
      alerts.add(TerritoryAlert(
        id: _id(territoryId, 'relatos-${category.name}', AlertKind.cidadao,
            today),
        territoryId: territoryId,
        indicatorId: null,
        kind: AlertKind.cidadao,
        severity:
            highUrgency >= 2 ? AlertSeverity.atencao : AlertSeverity.informativo,
        title: 'Relatos recorrentes: ${category.label.toLowerCase()}',
        summary: '${items.length} relatos da mesma categoria em '
            '${territoryById(territoryId).name} nos últimos 7 dias.',
        evidence: [
          '${items.length} relatos anônimos nos últimos 7 dias '
              '(o alerta começa em $clusterMinReports).',
          '$highUrgency marcados como urgência alta.',
        ],
        confidence: min(0.3 + items.length * 0.05, 0.55),
        limitations: const [
          'Relatos não são verificados e podem se referir ao mesmo fato.',
          'Quem tem menos acesso digital aparece menos: a ausência de relatos '
              'não significa ausência de problema.',
        ],
        humanAction: 'Verificar os relatos em campo antes de encaminhar.',
        leadDays: 0,
        reliable: false,
        date: today,
      ));
    });
    return alerts;
  }

  List<String> _limitations(IndicatorDefinition d, Forecast forecast) => [
        ...forecast.unreliableReasons,
        if (d.origin == DataOrigin.sintetico)
          'Dados sintéticos, gerados para demonstração: não representam '
              'medições reais do bairro.'
        else
          'Os valores são estimativas de modelos para uma área de cerca de '
              '10 km, não leituras de sensores no bairro: confira em estações '
              'oficiais.',
        if (forecast.mape != null)
          'O modelo projeta padrões recentes e não antecipa eventos novos, '
              'como obras, greves ou rompimentos.'
        else
          'Eventos extremos e localizados são difíceis de prever, sobretudo '
              'além de 3 dias.',
      ];

  double _excess(double value, double threshold) {
    if (threshold.abs() < 1e-6) return 0;
    return (value - threshold).abs() / threshold.abs();
  }

  String _side(IndicatorDefinition d) =>
      d.direction == RiskDirection.above ? 'acima' : 'abaixo';

  String _id(String territory, String subject, AlertKind kind, DateTime date) =>
      '${territory}_${subject}_${kind.name}_${compactDay(date)}';
}
