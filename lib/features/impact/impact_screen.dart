import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../domain/formatters.dart';
import '../../domain/impact_calculator.dart';
import '../../shared/common_widgets.dart';
import '../../state/alerts_controller.dart';
import '../../state/settings_controller.dart';
import '../../state/territory_controller.dart';

/// Relaciona o desempenho analítico a indicadores de benefício social.
class ImpactScreen extends StatelessWidget {
  const ImpactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final territory = context.watch<TerritoryController>();
    final alerts = context.watch<AlertsController>();
    final settings = context.watch<SettingsController>();
    final impact = const ImpactCalculator().compute(
      territory: territory.selected,
      snapshot: territory.snapshot,
      alerts: alerts.current,
      decisions: alerts.decisions,
      thresholds: settings.thresholds,
      now: territory.now,
    );
    final useful = impact.usefulRate;
    final error = impact.averageForecastError;

    return Scaffold(
      appBar: AppBar(title: Text('Impacto · ${territory.selected.name}')),
      body: PageBody(
        children: [
          const Text('Previsão boa só importa se chega a tempo de ajudar alguém. '
              'Estes números ligam a qualidade da análise ao benefício para '
              'as pessoas.'),
          ResponsiveGrid(
            minItemWidth: 240,
            children: [
              StatTile(
                icon: Icons.groups_outlined,
                value: formatCompact(impact.residentsCovered.toDouble()),
                label: 'moradores cobertos pelo monitoramento',
                note: 'População aproximada do distrito.',
              ),
              StatTile(
                icon: Icons.schedule,
                value: '${formatNumber(impact.averageLeadDays, decimals: 1)} dias',
                label: 'de antecedência média dos alertas de previsão',
                note: 'Tempo a mais para as equipes se organizarem.',
              ),
              StatTile(
                icon: Icons.water_drop_outlined,
                value: '${formatCompact(impact.waterAtRiskLiters)} L',
                label: 'de água acima do limiar nos próximos 7 dias',
                note: 'Estimativa com dados sintéticos, não é medição.',
              ),
              StatTile(
                icon: Icons.how_to_reg_outlined,
                value: formatPercent(impact.reviewRate),
                label: 'dos alertas revisados por pessoas',
                note: '${impact.alertsReviewed} de ${impact.alertsTotal} alertas.',
              ),
              StatTile(
                icon: Icons.verified_outlined,
                value: useful == null ? 'Sem dados' : formatPercent(useful),
                label: 'dos alertas revisados foram considerados procedentes',
                note: 'Avaliação humana da utilidade dos alertas.',
              ),
              StatTile(
                icon: Icons.analytics_outlined,
                value: error == null ? 'Sem dados' : formatPercent(error),
                label: 'de erro médio das previsões estatísticas',
                note: 'Teste com os últimos 7 dias reservados.',
              ),
            ],
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Como ler estes números', style: context.text.titleSmall),
                  const SizedBox(height: Gap.sm),
                  const Text('São estimativas de potencial, não resultados '
                      'comprovados. Medir o benefício real exigiria acompanhar, '
                      'com as equipes locais, o que mudou depois de cada alerta.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
