import 'dart:math';

import 'models.dart';

/// Previsão estatística interpretável: regressão linear (mínimos quadrados)
/// com ajuste por dia da semana. A escolha por um modelo simples é deliberada:
/// roda offline no aparelho e cada número pode ser explicado para o gestor.
class Forecaster {
  const Forecaster({this.horizonDays = 7, this.windowDays = 28});

  final int horizonDays;
  final int windowDays;

  static const int minTrainingDays = 14;
  static const double maxReliableMape = 0.25;
  static const int maxDataAgeDays = 3;

  Forecast forecast(IndicatorSeries series, DateTime now) {
    final history = series.history;
    final window = history.length > windowDays
        ? history.sublist(history.length - windowDays)
        : history;
    final reasons = <String>[];

    if (window.length < minTrainingDays) {
      reasons.add(
        'Histórico curto: ${window.length} dias, quando o mínimo são '
        '$minTrainingDays.',
      );
    }
    if (history.isNotEmpty) {
      final age = _daysBetween(history.last.date, now);
      if (age > maxDataAgeDays) {
        reasons.add('Dados desatualizados: a última medição tem $age dias.');
      }
    }

    final fit = _fit(window);
    final slope = fit?.slope ?? 0;
    final trend = _trendOf(slope, window);

    if (series.externalForecast.isNotEmpty) {
      return _fromExternal(series, window, slope, trend, reasons);
    }

    if (fit == null) {
      return Forecast(
        points: const [],
        method: 'Dados insuficientes para calcular a previsão',
        baseConfidence: 0.1,
        trend: trend,
        slopePerDay: slope,
        trainingDays: window.length,
        mape: null,
        unreliableReasons: reasons,
      );
    }

    final mape = backtestMape(window);
    if (mape != null && mape > maxReliableMape) {
      reasons.add(
        'Erro alto no teste com dados passados: '
        '${(mape * 100).toStringAsFixed(0)}%.',
      );
    }

    final last = window.last.date;
    final points = <ForecastPoint>[];
    for (var h = 1; h <= horizonDays; h++) {
      final date = last.add(Duration(days: h));
      final value = fit.predict(window.length - 1 + h, date.weekday);
      final margin =
          1.96 * fit.residualStd * sqrt(1 + h / max(window.length, 1));
      points.add(
        ForecastPoint(
          date: date,
          value: value,
          lower: value - margin,
          upper: value + margin,
        ),
      );
    }

    // Erro de 0% resulta em 0,95; erro de 25% ou mais fica em baixa confiança.
    var confidence = 0.95 - (mape ?? 0.4) * 2.2;
    if (reasons.isNotEmpty) confidence = min(confidence, 0.4);

    return Forecast(
      points: points,
      method:
          'Regressão linear com ajuste por dia da semana '
          '(${window.length} dias de treino)',
      baseConfidence: confidence.clamp(0.1, 0.95).toDouble(),
      trend: trend,
      slopePerDay: slope,
      trainingDays: window.length,
      mape: mape,
      unreliableReasons: reasons,
    );
  }

  Forecast _fromExternal(
    IndicatorSeries series,
    List<DataPoint> window,
    double slope,
    TrendDirection trend,
    List<String> reasons,
  ) {
    final std = _std(window.map((e) => e.value).toList());
    final points = <ForecastPoint>[];
    var h = 1;
    for (final p in series.externalForecast.take(horizonDays)) {
      final margin = 0.5 * std * sqrt(h.toDouble());
      points.add(
        ForecastPoint(
          date: p.date,
          value: p.value,
          lower: p.value - margin,
          upper: p.value + margin,
        ),
      );
      h++;
    }
    return Forecast(
      points: points,
      method: 'Modelo meteorológico da Open-Meteo',
      baseConfidence: reasons.isEmpty ? 0.85 : 0.4,
      trend: trend,
      slopePerDay: slope,
      trainingDays: window.length,
      mape: null,
      unreliableReasons: reasons,
    );
  }

  /// Treina sem os últimos 7 dias e mede o erro nesses 7 dias reservados.
  double? backtestMape(List<DataPoint> window) {
    const holdout = 7;
    if (window.length < holdout + 7) return null;
    final train = window.sublist(0, window.length - holdout);
    final test = window.sublist(window.length - holdout);
    final fit = _fit(train);
    if (fit == null) return null;

    var total = 0.0;
    var count = 0;
    for (var i = 0; i < test.length; i++) {
      final actual = test[i].value;
      if (actual.abs() < 1e-6) continue;
      final predicted = fit.predict(train.length + i, test[i].date.weekday);
      total += (actual - predicted).abs() / actual.abs();
      count++;
    }
    return count == 0 ? null : total / count;
  }

  _Fit? _fit(List<DataPoint> points) {
    if (points.length < 3) return null;
    final n = points.length;
    final meanX = (n - 1) / 2;
    final meanY = points.map((e) => e.value).reduce((a, b) => a + b) / n;
    var numerator = 0.0;
    var denominator = 0.0;
    for (var i = 0; i < n; i++) {
      numerator += (i - meanX) * (points[i].value - meanY);
      denominator += (i - meanX) * (i - meanX);
    }
    final slope = denominator == 0 ? 0.0 : numerator / denominator;
    final intercept = meanY - slope * meanX;

    final sums = <int, double>{};
    final counts = <int, int>{};
    for (var i = 0; i < n; i++) {
      final residual = points[i].value - (intercept + slope * i);
      final weekday = points[i].date.weekday;
      sums[weekday] = (sums[weekday] ?? 0) + residual;
      counts[weekday] = (counts[weekday] ?? 0) + 1;
    }
    final seasonal = {for (final k in sums.keys) k: sums[k]! / counts[k]!};

    var squared = 0.0;
    for (var i = 0; i < n; i++) {
      final predicted =
          intercept + slope * i + seasonal[points[i].date.weekday]!;
      squared += pow(points[i].value - predicted, 2);
    }
    final dof = max(n - 3, 1);
    return _Fit(intercept, slope, seasonal, sqrt(squared / dof));
  }

  TrendDirection _trendOf(double slope, List<DataPoint> window) {
    if (window.isEmpty) return TrendDirection.stable;
    final mean =
        window.map((e) => e.value.abs()).reduce((a, b) => a + b) /
        window.length;
    // Variação menor que 0,2% da média ao dia é tratada como estabilidade.
    final tolerance = max(mean * 0.002, 1e-6);
    if (slope > tolerance) return TrendDirection.rising;
    if (slope < -tolerance) return TrendDirection.falling;
    return TrendDirection.stable;
  }

  double _std(List<double> values) {
    if (values.length < 2) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final sum = values.fold<double>(0, (acc, v) => acc + pow(v - mean, 2));
    return sqrt(sum / (values.length - 1));
  }

  int _daysBetween(DateTime a, DateTime b) => DateTime(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime(a.year, a.month, a.day)).inDays;
}

class _Fit {
  const _Fit(this.intercept, this.slope, this.seasonal, this.residualStd);

  final double intercept;
  final double slope;
  final Map<int, double> seasonal;
  final double residualStd;

  double predict(int index, int weekday) =>
      intercept + slope * index + (seasonal[weekday] ?? 0);
}
