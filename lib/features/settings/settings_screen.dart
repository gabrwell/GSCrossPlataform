import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_router.dart';
import '../../core/app_theme.dart';
import '../../shared/common_widgets.dart';
import '../../state/reports_controller.dart';
import '../../state/settings_controller.dart';
import '../../state/territory_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _deleteData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Apagar seus relatos?'),
        content: const Text(
          'Todos os relatos salvos neste aparelho serão '
          'apagados e o consentimento será retirado. Isso não pode ser desfeito.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final settings = context.read<SettingsController>();
    await context.read<ReportsController>().deleteAll();
    await settings.setConsent(false);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Relatos apagados e consentimento retirado.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final territory = context.read<TerritoryController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: PageBody(
        children: [
          const SectionTitle('Aparência'),
          DropdownButtonFormField<AppThemeChoice>(
            initialValue: settings.theme,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Tema'),
            items: [
              for (final choice in AppThemeChoice.values)
                DropdownMenuItem(value: choice, child: Text(choice.label)),
            ],
            onChanged: (value) {
              if (value != null) settings.setTheme(value);
            },
          ),
          const SectionTitle('Alertas'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.tune, color: context.colors.primary),
                  title: const Text('Limiares de alerta'),
                  subtitle: const Text(
                    'Defina quando cada indicador gera alerta',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.pushNamed(Routes.thresholds),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Notificar alertas críticos'),
                  subtitle: const Text('Notificação local no Android'),
                  value: settings.notificationsEnabled,
                  onChanged: settings.setNotifications,
                ),
              ],
            ),
          ),
          const SectionTitle('Privacidade'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Consentimento para relatos anônimos'),
                  subtitle: const Text(
                    'Sem ele, os painéis continuam disponíveis, mas não é '
                    'possível registrar novos relatos.',
                  ),
                  value: settings.reportConsent,
                  onChanged: settings.setConsent,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.delete_forever_outlined,
                    color: context.colors.error,
                  ),
                  title: const Text('Apagar meus relatos'),
                  subtitle: const Text('Remove os relatos deste aparelho'),
                  onTap: () => _deleteData(context),
                ),
              ],
            ),
          ),
          const SectionTitle('Transparência'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.menu_book_outlined,
                    color: context.colors.primary,
                  ),
                  title: const Text('Metodologia e limitações'),
                  subtitle: const Text(
                    'Fontes, métricas, vieses e quando '
                    'não confiar nas previsões',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.pushNamed(Routes.methodology),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.diversity_3,
                    color: context.colors.primary,
                  ),
                  title: const Text('Benefício social'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.pushNamed(Routes.impact),
                ),
              ],
            ),
          ),
          const SectionTitle('Demonstração'),
          Card(
            child: SwitchListTile(
              title: const Text('Simular falta de conexão'),
              subtitle: const Text(
                'O clima passa a vir da cópia salva, como aconteceria sem internet.',
              ),
              value: settings.simulateOffline,
              onChanged: (value) async {
                await settings.setSimulateOffline(value);
                territory.setSimulateOffline(value);
                await territory.loadAll();
              },
            ),
          ),
        ],
      ),
    );
  }
}
