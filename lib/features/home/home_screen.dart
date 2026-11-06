import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_router.dart';
import '../../core/app_theme.dart';
import '../../domain/catalog.dart';
import '../../domain/formatters.dart';
import '../../domain/models.dart';
import '../../shared/common_widgets.dart';
import '../../shared/domain_cards.dart';
import '../../state/alerts_controller.dart';
import '../../state/territory_controller.dart';
import '../shell/app_shell.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final territory = context.watch<TerritoryController>();
    final alerts = context.watch<AlertsController>().current;
    final snapshot = territory.snapshot;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Território Vivo'),
        actions: const [SettingsAction()],
      ),
      body: PageBody(
        onRefresh: territory.loadAll,
        children: [
          const TerritorySelector(),
          if (snapshot == null && territory.status == LoadStatus.error)
            MessageView(
              icon: Icons.error_outline,
              title: 'Não deu para carregar',
              message: territory.errorMessage ?? 'Tente de novo.',
              actionLabel: 'Tentar de novo',
              onAction: territory.loadAll,
            )
          else if (snapshot == null)
            const LoadingView()
          else ...[
            const ConnectionBanner(),
            _Headline(territory: territory.selected, alerts: alerts),
            const HumanDecisionNotice(),
            const SectionTitle(
              'Painéis do bairro',
              subtitle: 'Toque para ver indicadores, histórico e tendência',
            ),
            ResponsiveGrid(
              minItemWidth: 220,
              children: [
                for (final kind in DashboardKind.values)
                  _DashboardSummary(kind: kind, alerts: alerts),
              ],
            ),
            SectionTitle(
              'Alertas prioritários',
              action: TextButton(
                onPressed: () => context.goNamed(Routes.alerts),
                child: const Text('Ver todos'),
              ),
            ),
            if (alerts.isEmpty)
              const MessageView(
                icon: Icons.task_alt,
                title: 'Nenhum alerta agora',
                message:
                    'Os indicadores estão dentro dos limiares configurados.',
              )
            else
              for (final alert in alerts.take(3)) AlertCard(alert: alert),
            _ImpactLink(population: territory.selected.population),
          ],
        ],
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.territory, required this.alerts});

  final Territory territory;
  final List<TerritoryAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final critical = alerts
        .where((a) => a.severity == AlertSeverity.critico)
        .length;
    final message = alerts.isEmpty
        ? 'Sem sinais de risco no momento.'
        : '${alerts.length} ${alerts.length == 1 ? 'sinal' : 'sinais'} para '
              'análise${critical > 0 ? ', $critical crítico${critical > 1 ? 's' : ''}' : ''}.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(territory.name, style: context.text.headlineSmall),
        ),
        Text(message, style: context.text.bodyLarge),
      ],
    );
  }
}

class _DashboardSummary extends StatelessWidget {
  const _DashboardSummary({required this.kind, required this.alerts});

  final DashboardKind kind;
  final List<TerritoryAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final ids = indicatorsFor(kind).map((i) => i.id).toSet();
    final count = alerts.where((a) => ids.contains(a.indicatorId)).length;
    final text = count == 0
        ? 'Sem alertas'
        : '$count ${count == 1 ? 'alerta' : 'alertas'}';
    return Card(
      child: Semantics(
        button: true,
        label: 'Painel de ${kind.label}: $text. Abrir painel.',
        excludeSemantics: true,
        child: InkWell(
          onTap: () => context.goNamed(
            Routes.dashboards,
            queryParameters: {'aba': kind.name},
          ),
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Row(
              children: [
                Icon(dashboardIcon(kind), color: context.colors.primary),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(kind.label, style: context.text.titleMedium),
                      Text(text, style: context.text.bodyMedium),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImpactLink extends StatelessWidget {
  const _ImpactLink({required this.population});

  final int population;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.xs,
        ),
        leading: Icon(Icons.diversity_3, color: context.colors.primary),
        title: const Text('Benefício social'),
        subtitle: Text(
          'Cerca de ${formatCompact(population.toDouble())} moradores cobertos. '
          'Veja o impacto das análises.',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.pushNamed(Routes.impact),
      ),
    );
  }
}
