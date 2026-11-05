import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models.dart';

class ClimateUnavailable implements Exception {
  const ClimateUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Dados reais de clima e qualidade do ar da Open-Meteo (sem chave de API).
class OpenMeteoService {
  OpenMeteoService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 12);
  static const String _tz = 'America%2FSao_Paulo';

  Future<List<IndicatorSeries>> fetch(Territory t, DateTime now) async {
    final results = await Future.wait([
      _get('https://api.open-meteo.com/v1/forecast'
          '?latitude=${t.latitude}&longitude=${t.longitude}'
          '&daily=temperature_2m_max,precipitation_sum'
          '&past_days=30&forecast_days=7&timezone=$_tz'),
      _get('https://air-quality-api.open-meteo.com/v1/air-quality'
          '?latitude=${t.latitude}&longitude=${t.longitude}'
          '&hourly=us_aqi&past_days=30&forecast_days=5&timezone=$_tz'),
    ]);
    return [
      ...parseWeather(results[0], now),
      parseAirQuality(results[1], now),
    ];
  }

  Future<Map<String, dynamic>> _get(String url) async {
    final http.Response response;
    try {
      response = await _client.get(Uri.parse(url)).timeout(_timeout);
    } catch (_) {
      throw const ClimateUnavailable('Sem resposta do serviço de clima.');
    }
    if (response.statusCode != 200) {
      throw ClimateUnavailable(
          'O serviço de clima respondeu com erro ${response.statusCode}.');
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  static List<IndicatorSeries> parseWeather(
    Map<String, dynamic> json,
    DateTime now,
  ) {
    final daily = json['daily'] as Map<String, dynamic>;
    final days = (daily['time'] as List).cast<String>();
    return [
      _split('temperatura', days, daily['temperature_2m_max'] as List, now),
      _split('chuva', days, daily['precipitation_sum'] as List, now),
    ];
  }

  static IndicatorSeries parseAirQuality(
    Map<String, dynamic> json,
    DateTime now,
  ) {
    final hourly = json['hourly'] as Map<String, dynamic>;
    final times = (hourly['time'] as List).cast<String>();
    final values = hourly['us_aqi'] as List;

    // A API entrega valores por hora; o painel trabalha com a média diária.
    final sums = <String, double>{};
    final counts = <String, int>{};
    for (var i = 0; i < times.length; i++) {
      final value = values[i];
      if (value == null) continue;
      final day = times[i].substring(0, 10);
      sums[day] = (sums[day] ?? 0) + (value as num).toDouble();
      counts[day] = (counts[day] ?? 0) + 1;
    }
    final days = sums.keys.toList()..sort();
    final averages = [for (final d in days) sums[d]! / counts[d]!];
    return _split('ar', days, averages, now);
  }

  /// Datas até ontem são histórico; de hoje em diante são previsão do modelo.
  static IndicatorSeries _split(
    String id,
    List<String> days,
    List<dynamic> values,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final history = <DataPoint>[];
    final forecast = <DataPoint>[];
    for (var i = 0; i < days.length; i++) {
      final raw = values[i];
      if (raw == null) continue;
      final date = DateTime.parse(days[i]);
      final point = DataPoint(date, (raw as num).toDouble());
      (date.isBefore(today) ? history : forecast).add(point);
    }
    return IndicatorSeries(
      indicatorId: id,
      history: history,
      externalForecast: forecast,
      fetchedAt: now,
    );
  }
}
