import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Acesso único à persistência local, escondendo as chaves e o JSON das demais
/// camadas. Trocar o mecanismo de armazenamento só afetaria esta classe.
class LocalStore {
  LocalStore(this._prefs);

  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  bool? getBool(String key) => _prefs.getBool(key);
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  Future<void> remove(String key) => _prefs.remove(key);

  /// Dados corrompidos não podem derrubar o app: devolve nulo e segue.
  Object? readJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  Future<void> writeJson(String key, Object value) =>
      _prefs.setString(key, jsonEncode(value));
}
