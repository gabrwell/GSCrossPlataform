import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/models.dart';

/// Notificações locais para alertas críticos (somente Android).
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  Future<void>? _initialization;
  bool _ready = false;

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Chamado depois de `runApp`: o pedido de permissão abre um diálogo e não
  /// pode atrasar a abertura do app.
  Future<void> init() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (!_supported) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (error) {
      debugPrint('Notificações indisponíveis: ${error.runtimeType}');
    }
  }

  Future<void> showCriticalAlert(TerritoryAlert alert) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.show(
        id: alert.id.hashCode & 0x7FFFFFFF,
        title: alert.title,
        body: 'Sinal para análise humana. Abra o app para ver a evidência.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'alertas_criticos',
            'Alertas críticos',
            channelDescription: 'Sinais críticos para análise humana',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (error) {
      debugPrint('Notificação não enviada: ${error.runtimeType}');
    }
  }
}
