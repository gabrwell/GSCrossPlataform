import '../domain/models.dart';
import 'local_store.dart';
import 'open_meteo_service.dart';
import 'synthetic_data_service.dart';

/// Combina as fontes de dados e aplica a estratégia offline: tenta a API e,
/// se falhar, usa o último clima salvo. Os sintéticos são gerados no aparelho.
class TerritoryRepository {
  TerritoryRepository({
    required this.store,
    required this.climate,
    required this.synthetic,
  });

  final LocalStore store;
  final OpenMeteoService climate;
  final SyntheticDataService synthetic;

  /// Modo de demonstração: simula falta de conexão sem desligar o Wi-Fi.
  bool simulateOffline = false;

  String _key(String territoryId) => 'climate_cache_$territoryId';

  Future<TerritorySnapshot> load(Territory t, DateTime now) async {
    final syntheticSeries = await synthetic.fetch(t, now);

    var fromCache = false;
    var unavailable = false;
    List<IndicatorSeries> climateSeries;
    try {
      if (simulateOffline) {
        throw const ClimateUnavailable('Modo sem conexão ativado.');
      }
      climateSeries = await climate.fetch(t, now);
      await store.writeJson(
        _key(t.id),
        climateSeries.map((s) => s.toJson()).toList(),
      );
    } on ClimateUnavailable {
      final cached = _readCache(t.id);
      climateSeries = cached ?? const [];
      fromCache = cached != null;
      unavailable = cached == null;
    }

    return TerritorySnapshot(
      territoryId: t.id,
      climateFromCache: fromCache,
      climateUnavailable: unavailable,
      series: {
        for (final s in [...syntheticSeries, ...climateSeries])
          s.indicatorId: s,
      },
    );
  }

  List<IndicatorSeries>? _readCache(String territoryId) {
    final json = store.readJson(_key(territoryId));
    if (json is! List) return null;
    try {
      return json
          .map((e) => IndicatorSeries.fromJson(e as Map<String, dynamic>))
          .toList();
    } on TypeError {
      return null;
    } on FormatException {
      return null;
    }
  }
}
