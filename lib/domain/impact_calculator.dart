import 'catalog.dart';
import 'forecasting.dart';
import 'models.dart';

/// Indicadores que relacionam o desempenho analítico ao benefício social.
class ImpactSummary {
  const ImpactSummary({
    required this.residentsCovered,
    required this.alertsTotal,
    required this.alertsReviewed,
    required this.alertsConfirmed,
    required this.averageLeadDays,
    required this.waterAtRiskLiters,
    required this.averageForecastError,
  });

  final int residentsCovered;
  final int alertsTotal;
  final int alertsReviewed;
  final int alertsConfirmed;

  /// Dias de antecedência médios dos alertas de previsão.
  final double averageLeadDays;

  /// Água acima do limiar projetada para os próximos 7 dias (estimativa).
  final double waterAtRiskLiters;

  /// Erro médio das previsões estatísticas (nulo se não houver teste).
  final double? averageForecastError;

  double get reviewRate => alertsTotal == 0 ? 0 : alertsReviewed / alertsTotal;

  /// Entre os alertas revisados, quantos as pessoas consideraram procedentes.
  double? get usefulRate =>
      alertsReviewed == 0 ? null : alertsConfirmed / alertsReviewed;
}

class ImpactCalculator {
  const ImpactCalculator({this.forecaster = const Forecaster()});

  final Forecaster forecaster;

  ImpactSummary compute({
    required Territory territory,
    required TerritorySnapshot? snapshot,
    required List<TerritoryAlert> alerts,
    required Map<String, AlertDecision> decisions,
    required Map<String, double> thresholds,
    required DateTime now,
  }) {
    var reviewed = 0;
    var confirmed = 0;
    for (final alert in alerts) {
      final status = decisions[alert.id]?.status ?? DecisionStatus.pendente;
      if (status == DecisionStatus.pendente) continue;
      reviewed++;
      if (status == DecisionStatus.confirmado) confirmed++;
    }

    final forecastAlerts = alerts.where((a) => a.kind == AlertKind.previsao);
    final averageLead = forecastAlerts.isEmpty
        ? 0.0
        : forecastAlerts.map((a) => a.leadDays).reduce((a, b) => a + b) /
              forecastAlerts.length;

    var waterAtRisk = 0.0;
    final errors = <double>[];
    if (snapshot != null) {
      for (final series in snapshot.series.values) {
        final forecast = forecaster.forecast(series, now);
        if (forecast.mape != null) errors.add(forecast.mape!);
        if (series.indicatorId == 'agua') {
          final definition = indicatorById('agua');
          final threshold = thresholds['agua'] ?? definition.defaultThreshold;
          for (final point in forecast.points) {
            if (point.value > threshold) {
              waterAtRisk += (point.value - threshold) * territory.population;
            }
          }
        }
      }
    }

    return ImpactSummary(
      residentsCovered: territory.population,
      alertsTotal: alerts.length,
      alertsReviewed: reviewed,
      alertsConfirmed: confirmed,
      averageLeadDays: averageLead,
      waterAtRiskLiters: waterAtRisk,
      averageForecastError: errors.isEmpty
          ? null
          : errors.reduce((a, b) => a + b) / errors.length,
    );
  }
}
