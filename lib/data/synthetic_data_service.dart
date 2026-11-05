import 'dart:math';

import '../domain/models.dart';

/// API simulada de dados sintéticos de recursos e serviços.
///
/// Os valores são determinísticos: mesmo bairro, indicador e data sempre geram
/// o mesmo número, então o histórico não muda a cada abertura do app.
class SyntheticDataService {
  const SyntheticDataService({
    this.historyDays = 60,
    this.latency = const Duration(milliseconds: 350),
  });

  final int historyDays;
  final Duration latency;

  Future<List<IndicatorSeries>> fetch(Territory t, DateTime now) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return generate(t, now);
  }

  List<IndicatorSeries> generate(Territory t, DateTime now) => [
        _series(t, now, 'agua', 158 * t.waterFactor, 0.035, 0.03, 12),
        _series(t, now, 'energia', 5.4 * t.energyFactor, 0.05, 0.03, 8),
        _series(t, now, 'residuos', 1.14 * t.wasteFactor, 0.07, 0.03, 15),
        _series(t, now, 'reservatorio', t.reservoirBase, 0.0, 0.006, 14),
        _series(t, now, 'atendimentos', 31 * t.serviceFactor, 0.12, 0.04, 8),
        _series(t, now, 'zeladoria', 6.2 * t.serviceFactor, 0.14, 0.06, 10),
        _series(t, now, 'espera', 10 * t.serviceFactor, 0.0, 0.015, 12),
      ];

  IndicatorSeries _series(
    Territory t,
    DateTime now,
    String id,
    double base,
    double weeklyAmplitude,
    double noise,
    double slowAmplitudePercent,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final points = <DataPoint>[];
    final phase = _hash('${t.id}:$id:phase') % 360 * pi / 180;
    for (var back = historyDays; back >= 1; back--) {
      final date = today.subtract(Duration(days: back));
      final day = date.difference(DateTime(2020)).inDays;
      final random = Random(_hash('${t.id}:$id:$day'));
      // Ciclo lento de 75 dias: cria tendências locais que nunca divergem.
      final slow = sin(2 * pi * day / 75 + phase) * slowAmplitudePercent / 100;
      final weekend = date.weekday >= DateTime.saturday ? -1.0 : 0.4;
      final jitter = (random.nextDouble() * 2 - 1) * noise;
      final value = base * (1 + slow + weekend * weeklyAmplitude + jitter);
      points.add(DataPoint(date, value));
    }
    return IndicatorSeries(indicatorId: id, history: points, fetchedAt: now);
  }

  /// FNV-1a. `String.hashCode` varia entre plataformas; este não.
  int _hash(String text) {
    var hash = 0x811C9DC5;
    for (final unit in text.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }
}
