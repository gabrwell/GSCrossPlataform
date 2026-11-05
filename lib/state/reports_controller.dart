import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/local_store.dart';
import '../domain/models.dart';

/// Relatos de ocorrência, guardados somente no aparelho.
class ReportsController extends ChangeNotifier {
  ReportsController(this._store, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    _load();
  }

  static const _key = 'citizen_reports';

  final LocalStore _store;
  final DateTime Function() _clock;
  final Random _random = Random();
  List<CitizenReport> _reports = [];

  List<CitizenReport> get all => List.unmodifiable(_reports);

  List<CitizenReport> forTerritory(String id) =>
      _reports.where((r) => r.territoryId == id).toList();

  void _load() {
    final json = _store.readJson(_key);
    if (json is! List) return;
    _reports = json
        .map((e) => CitizenReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> add({
    required String territoryId,
    required ReportCategory category,
    required String description,
    required int urgency,
  }) async {
    final now = _clock();
    // Identificador aleatório, sem relação com pessoa ou aparelho.
    final id = List.generate(12, (_) => _random.nextInt(16).toRadixString(16))
        .join();
    _reports = [
      CitizenReport(
        id: id,
        territoryId: territoryId,
        category: category,
        description: description.trim(),
        urgency: urgency,
        day: DateTime(now.year, now.month, now.day),
      ),
      ..._reports,
    ];
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String id) async {
    _reports = _reports.where((r) => r.id != id).toList();
    notifyListeners();
    await _persist();
  }

  Future<void> deleteAll() async {
    _reports = [];
    notifyListeners();
    await _store.remove(_key);
  }

  Future<void> _persist() =>
      _store.writeJson(_key, _reports.map((r) => r.toJson()).toList());
}
