import 'package:flutter/foundation.dart';

import '../data/local_store.dart';
import '../domain/catalog.dart';

enum AppThemeChoice {
  system('Seguir o sistema'),
  light('Claro'),
  dark('Escuro'),
  highContrast('Alto contraste');

  const AppThemeChoice(this.label);
  final String label;
}

/// Estado global de preferências: tema, limiares, consentimento e notificações.
class SettingsController extends ChangeNotifier {
  SettingsController(this._store) {
    _load();
  }

  final LocalStore _store;

  static const _kTheme = 'theme';
  static const _kThresholds = 'thresholds';
  static const _kOnboarded = 'onboarded';
  static const _kConsent = 'consent';
  static const _kNotifications = 'notifications';
  static const _kOffline = 'simulate_offline';

  AppThemeChoice _theme = AppThemeChoice.system;
  Map<String, double> _thresholds = defaultThresholds();
  bool _onboarded = false;
  bool _consent = false;
  bool _notifications = true;
  bool _simulateOffline = false;

  AppThemeChoice get theme => _theme;
  Map<String, double> get thresholds => Map.unmodifiable(_thresholds);
  bool get onboarded => _onboarded;
  bool get reportConsent => _consent;
  bool get notificationsEnabled => _notifications;
  bool get simulateOffline => _simulateOffline;

  void _load() {
    final themeName = _store.getString(_kTheme);
    _theme = AppThemeChoice.values.firstWhere(
      (t) => t.name == themeName,
      orElse: () => AppThemeChoice.system,
    );
    final saved = _store.readJson(_kThresholds);
    if (saved is Map) {
      saved.forEach((key, value) {
        if (_thresholds.containsKey(key) && value is num) {
          _thresholds[key as String] = value.toDouble();
        }
      });
    }
    _onboarded = _store.getBool(_kOnboarded) ?? false;
    _consent = _store.getBool(_kConsent) ?? false;
    _notifications = _store.getBool(_kNotifications) ?? true;
    _simulateOffline = _store.getBool(_kOffline) ?? false;
  }

  Future<void> setTheme(AppThemeChoice value) async {
    _theme = value;
    notifyListeners();
    await _store.setString(_kTheme, value.name);
  }

  Future<void> saveThresholds(Map<String, double> values) async {
    _thresholds = {..._thresholds, ...values};
    notifyListeners();
    await _store.writeJson(_kThresholds, _thresholds);
  }

  Future<void> resetThresholds() async {
    _thresholds = defaultThresholds();
    notifyListeners();
    await _store.remove(_kThresholds);
  }

  /// Conclui a etapa inicial. O app funciona mesmo sem consentimento; apenas o
  /// registro de relatos depende dele.
  Future<void> completeOnboarding({required bool consent}) async {
    _onboarded = true;
    _consent = consent;
    notifyListeners();
    await _store.setBool(_kOnboarded, true);
    await _store.setBool(_kConsent, consent);
  }

  Future<void> setConsent(bool value) async {
    _consent = value;
    notifyListeners();
    await _store.setBool(_kConsent, value);
  }

  Future<void> setNotifications(bool value) async {
    _notifications = value;
    notifyListeners();
    await _store.setBool(_kNotifications, value);
  }

  Future<void> setSimulateOffline(bool value) async {
    _simulateOffline = value;
    notifyListeners();
    await _store.setBool(_kOffline, value);
  }
}
