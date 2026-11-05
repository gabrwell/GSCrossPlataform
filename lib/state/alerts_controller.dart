import 'package:flutter/foundation.dart';

import '../data/local_store.dart';
import '../data/notification_service.dart';
import '../domain/alert_engine.dart';
import '../domain/catalog.dart';
import '../domain/models.dart';
import 'reports_controller.dart';
import 'settings_controller.dart';
import 'territory_controller.dart';

/// Recalcula os alertas sempre que dados, limiares ou relatos mudam, e guarda
/// as decisões humanas. Uma decisão só é registrada; o app não executa nada.
class AlertsController extends ChangeNotifier {
  AlertsController({
    required this._territory,
    required this._settings,
    required this._reports,
    required this._store,
    required this._notifications,
    this._engine = const AlertEngine(),
  }) {
    _loadPersisted();
    _territory.addListener(_recompute);
    _settings.addListener(_recompute);
    _reports.addListener(_recompute);
    _recompute();
  }

  static const _kDecisions = 'alert_decisions';
  static const _kNotified = 'alerts_notified';

  final TerritoryController _territory;
  final SettingsController _settings;
  final ReportsController _reports;
  final LocalStore _store;
  final NotificationService _notifications;
  final AlertEngine _engine;

  Map<String, List<TerritoryAlert>> _byTerritory = {};
  Map<String, AlertDecision> _decisions = {};
  Set<String> _notified = {};

  List<TerritoryAlert> get current => forTerritory(_territory.selected.id);
  List<TerritoryAlert> forTerritory(String id) => _byTerritory[id] ?? const [];
  Map<String, AlertDecision> get decisions => Map.unmodifiable(_decisions);

  List<TerritoryAlert> forIndicator(String indicatorId) =>
      current.where((a) => a.indicatorId == indicatorId).toList();

  TerritoryAlert? byId(String id) {
    for (final alerts in _byTerritory.values) {
      for (final alert in alerts) {
        if (alert.id == id) return alert;
      }
    }
    return null;
  }

  DecisionStatus statusOf(String alertId) =>
      _decisions[alertId]?.status ?? DecisionStatus.pendente;

  int get pendingCount =>
      current.where((a) => statusOf(a.id) == DecisionStatus.pendente).length;

  Future<void> decide(
    String alertId,
    DecisionStatus status,
    String note,
  ) async {
    _decisions = {
      ..._decisions,
      alertId: AlertDecision(
        alertId: alertId,
        status: status,
        note: note.trim(),
        decidedAt: _territory.now,
      ),
    };
    notifyListeners();
    await _store.writeJson(
      _kDecisions,
      _decisions.values.map((d) => d.toJson()).toList(),
    );
  }

  void _loadPersisted() {
    final decisions = _store.readJson(_kDecisions);
    if (decisions is List) {
      _decisions = {
        for (final item in decisions)
          (item as Map<String, dynamic>)['id'] as String:
              AlertDecision.fromJson(item),
      };
    }
    final notified = _store.readJson(_kNotified);
    if (notified is List) _notified = notified.cast<String>().toSet();
  }

  void _recompute() {
    final result = <String, List<TerritoryAlert>>{};
    for (final territory in kTerritories) {
      final snapshot = _territory.snapshotOf(territory.id);
      if (snapshot == null) continue;
      result[territory.id] = _engine.generate(
        snapshot: snapshot,
        thresholds: _settings.thresholds,
        reports: _reports.forTerritory(territory.id),
        now: _territory.now,
      );
    }
    _byTerritory = result;
    notifyListeners();
    _notifyCritical();
  }

  /// Avisa uma única vez sobre cada alerta crítico do bairro selecionado.
  void _notifyCritical() {
    if (!_settings.notificationsEnabled) return;
    final fresh = current.where(
      (a) => a.severity == AlertSeverity.critico && !_notified.contains(a.id),
    );
    if (fresh.isEmpty) return;
    for (final alert in fresh.toList()) {
      _notified.add(alert.id);
      _notifications.showCriticalAlert(alert);
    }
    _store.writeJson(_kNotified, _notified.toList());
  }

  @override
  void dispose() {
    _territory.removeListener(_recompute);
    _settings.removeListener(_recompute);
    _reports.removeListener(_recompute);
    super.dispose();
  }
}
