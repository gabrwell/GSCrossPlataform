import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../domain/models.dart';
import '../../shared/common_widgets.dart';
import '../../shared/domain_cards.dart';
import '../../state/alerts_controller.dart';
import '../../state/territory_controller.dart';
import '../shell/app_shell.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  /// Estado local: o filtro não precisa existir fora desta tela.
  AlertSeverity? _severity;
  bool _onlyPending = false;

  @override
  Widget build(BuildContext context) {
    final territory = context.watch<TerritoryController>();
    final controller = context.watch<AlertsController>();
    final all = controller.current;
    final visible = all.where((a) {
      if (_severity != null && a.severity != _severity) return false;
      if (_onlyPending &&
          controller.statusOf(a.id) != DecisionStatus.pendente) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Alertas · ${territory.selected.name}'),
        actions: const [SettingsAction()],
      ),
      body: PageBody(
        onRefresh: territory.loadAll,
        children: [
          const HumanDecisionNotice(),
          const ConnectionBanner(),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.xs,
            children: [
              ChoiceChip(
                label: const Text('Todos'),
                selected: _severity == null,
                onSelected: (_) => setState(() => _severity = null),
              ),
              for (final severity in AlertSeverity.values.reversed)
                ChoiceChip(
                  label: Text(severity.label),
                  selected: _severity == severity,
                  onSelected: (_) => setState(() => _severity = severity),
                ),
              FilterChip(
                label: const Text('Só pendentes'),
                selected: _onlyPending,
                onSelected: (value) => setState(() => _onlyPending = value),
              ),
            ],
          ),
          if (territory.snapshot == null && territory.isLoading)
            const LoadingView(message: 'Calculando alertas…')
          else if (territory.snapshot == null)
            MessageView(
              icon: Icons.error_outline,
              title: 'Não deu para calcular os alertas',
              message: territory.errorMessage ?? 'Os dados não carregaram.',
              actionLabel: 'Tentar de novo',
              onAction: territory.loadAll,
            )
          else if (visible.isEmpty)
            MessageView(
              icon: Icons.task_alt,
              title: all.isEmpty ? 'Nenhum alerta agora' : 'Nada neste filtro',
              message: all.isEmpty
                  ? 'Os indicadores do bairro estão dentro dos limiares.'
                  : 'Mude o filtro para ver os outros ${all.length} alertas.',
            )
          else
            ResponsiveGrid(
              minItemWidth: 360,
              children: [for (final a in visible) AlertCard(alert: a)],
            ),
        ],
      ),
    );
  }
}
