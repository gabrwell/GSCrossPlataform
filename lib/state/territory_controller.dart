import 'package:flutter/foundation.dart';

import '../data/local_store.dart';
import '../data/territory_repository.dart';
import '../domain/catalog.dart';
import '../domain/models.dart';

enum LoadStatus { idle, loading, ready, error }

/// Estado global dos dados: bairro selecionado e dados de todos os bairros,
/// compartilhados entre início, painéis, alertas e mapa.
class TerritoryController extends ChangeNotifier {
  TerritoryController({
    required this._repository,
    required this._store,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _selectedId = _store.getString(_kSelected) ?? kTerritories.first.id;
  }

  static const _kSelected = 'selected_territory';

  final TerritoryRepository _repository;
  final LocalStore _store;
  final DateTime Function() _clock;

  late String _selectedId;
  final Map<String, TerritorySnapshot> _snapshots = {};
  LoadStatus _status = LoadStatus.idle;
  String? _errorMessage;

  Territory get selected => territoryById(_selectedId);
  TerritorySnapshot? get snapshot => _snapshots[_selectedId];
  TerritorySnapshot? snapshotOf(String id) => _snapshots[id];
  Iterable<TerritorySnapshot> get snapshots => _snapshots.values;
  LoadStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == LoadStatus.loading;
  DateTime get now => _clock();

  void setSimulateOffline(bool value) {
    _repository.simulateOffline = value;
  }

  void select(String id) {
    if (id == _selectedId) return;
    _selectedId = id;
    notifyListeners();
    _store.setString(_kSelected, id);
  }

  Future<void> loadAll() async {
    if (isLoading) return;
    _status = LoadStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final now = _clock();
      final results = await Future.wait(
        kTerritories.map((t) => _repository.load(t, now)),
      );
      for (final snapshot in results) {
        _snapshots[snapshot.territoryId] = snapshot;
      }
      _status = LoadStatus.ready;
    } catch (error) {
      debugPrint('Falha ao carregar dados: ${error.runtimeType}');
      _errorMessage = 'Não foi possível carregar os dados do território.';
      _status = LoadStatus.error;
    }
    notifyListeners();
  }
}
