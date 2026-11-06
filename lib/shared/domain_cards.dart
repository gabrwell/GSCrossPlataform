import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/app_router.dart';
import '../core/app_theme.dart';
import '../domain/catalog.dart';
import '../domain/forecasting.dart';
import '../domain/formatters.dart';
import '../domain/models.dart';
import '../state/alerts_controller.dart';
import 'common_widgets.dart';
import 'indicator_chart.dart';

IconData indicatorIcon(String id) => switch (id) {
  'agua' => Icons.water_drop_outlined,
  'energia' => Icons.bolt_outlined,
  'residuos' => Icons.delete_outline,
  'reservatorio' => Icons.waves,
  'temperatura' => Icons.thermostat,
  'chuva' => Icons.umbrella_outlined,
  'ar' => Icons.air,
  'atendimentos' => Icons.local_hospital_outlined,
  'zeladoria' => Icons.construction,
  'espera' => Icons.hourglass_bottom,
  _ => Icons.insights,
};

IconData dashboardIcon(DashboardKind kind) => switch (kind) {
  DashboardKind.recursos => Icons.water_drop_outlined,
  DashboardKind.clima => Icons.wb_sunny_outlined,
  DashboardKind.servicos => Icons.health_and_safety_outlined,
};

IconData trendIcon(TrendDirection trend) => switch (trend) {
  TrendDirection.rising => Icons.trending_up,
  TrendDirection.stable => Icons.trending_flat,
  TrendDirection.falling => Icons.trending_down,
};

/// Cartão de indicador: valor atual, tendência, situação e minigráfico.
class IndicatorCard extends StatelessWidget {
  const IndicatorCard({
    super.key,
    required this.definition,
    required this.series,
    required this.threshold,
    required this.now,
  });

  final IndicatorDefinition definition;
  final IndicatorSeries series;
  final double threshold;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final forecast = const Forecaster().forecast(series, now);
    final latest = series.latest;
    final breached = latest != null && definition.breaches(latest, threshold);
    final recent = series.history.length > 30
        ? series.history.sublist(series.history.length - 30)
        : series.history;
    final valueText = latest == null
        ? 'Sem dado'
        : formatValue(latest, definition);

    return Card(
      child: Semantics(
        button: true,
        label:
            '${definition.name}: $valueText, tendência '
            '${forecast.trend.label}. '
            '${breached ? 'Além do limiar. ' : 'Dentro do limiar. '}'
            'Abrir detalhes.',
        excludeSemantics: true,
        child: InkWell(
          onTap: () => context.pushNamed(
            Routes.indicator,
            pathParameters: {'indicatorId': definition.id},
          ),
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      indicatorIcon(definition.id),
                      color: context.colors.primary,
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Text(
                        definition.name,
                        style: context.text.titleSmall,
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                const SizedBox(height: Gap.sm),
                Text(valueText, style: context.text.headlineSmall),
                const SizedBox(height: Gap.sm),
                SizedBox(
                  height: 52,
                  child: Sparkline(
                    values: recent.map((e) => e.value).toList(),
                    color: context.semantic.history,
                  ),
                ),
                const SizedBox(height: Gap.sm),
                Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.xs,
                  children: [
                    StatusPill(
                      label: forecast.trend.label,
                      icon: trendIcon(forecast.trend),
                      colors: context.semantic.info,
                    ),
                    StatusPill(
                      label: breached ? 'Além do limiar' : 'Dentro do limiar',
                      icon: breached ? Icons.warning_amber : Icons.check,
                      colors: breached
                          ? context.semantic.critical
                          : context.semantic.positive,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cartão de alerta usado na lista, no início e no detalhe de indicador.
class AlertCard extends StatelessWidget {
  const AlertCard({super.key, required this.alert});

  final TerritoryAlert alert;

  @override
  Widget build(BuildContext context) {
    final status = context.select<AlertsController, DecisionStatus>(
      (c) => c.statusOf(alert.id),
    );
    final indicator = alert.indicatorId;
    return Card(
      child: Semantics(
        button: true,
        label:
            'Alerta ${alert.severity.label}: ${alert.title}. '
            'Confiança ${alert.confidenceLevel.label}. ${status.label}. '
            'Abrir justificativa.',
        excludeSemantics: true,
        child: InkWell(
          onTap: () => context.pushNamed(
            Routes.alertDetail,
            pathParameters: {'alertId': alert.id},
          ),
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SeverityBadge(alert.severity),
                    if (!alert.reliable)
                      StatusPill(
                        label: 'Baixa confiabilidade',
                        icon: Icons.report_problem_outlined,
                        colors: context.semantic.attention,
                      ),
                    Text(alert.kind.label, style: context.text.labelMedium),
                  ],
                ),
                const SizedBox(height: Gap.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      indicator == null
                          ? Icons.campaign_outlined
                          : indicatorIcon(indicator),
                      color: context.colors.primary,
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Text(alert.title, style: context.text.titleSmall),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.xs),
                Text(alert.summary, style: context.text.bodyMedium),
                const SizedBox(height: Gap.sm),
                ConfidenceMeter(alert.confidence),
                const SizedBox(height: Gap.sm),
                Text(
                  status.label,
                  style: context.text.labelMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grade com todos os indicadores de um painel.
class IndicatorGrid extends StatelessWidget {
  const IndicatorGrid({
    super.key,
    required this.kind,
    required this.snapshot,
    required this.thresholds,
    required this.now,
  });

  final DashboardKind kind;
  final TerritorySnapshot snapshot;
  final Map<String, double> thresholds;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      minItemWidth: 280,
      children: [
        for (final definition in indicatorsFor(kind))
          if (snapshot.series[definition.id] != null)
            IndicatorCard(
              definition: definition,
              series: snapshot.series[definition.id]!,
              threshold:
                  thresholds[definition.id] ?? definition.defaultThreshold,
              now: now,
            ),
      ],
    );
  }
}
