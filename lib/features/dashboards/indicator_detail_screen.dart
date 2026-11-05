import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_router.dart';
import '../../core/app_theme.dart';
import '../../domain/catalog.dart';
import '../../domain/forecasting.dart';
import '../../domain/formatters.dart';
import '../../domain/models.dart';
import '../../shared/common_widgets.dart';
import '../../shared/domain_cards.dart';
import '../../shared/indicator_chart.dart';
import '../../state/alerts_controller.dart';
import '../../state/settings_controller.dart';
import '../../state/territory_controller.dart';

class IndicatorDetailScreen extends StatefulWidget {
  const IndicatorDetailScreen({super.key, required this.indicatorId});

  final String indicatorId;

  @override
  State<IndicatorDetailScreen> createState() => _IndicatorDetailScreenState();
}

class _IndicatorDetailScreenState extends State<IndicatorDetailScreen> {
  /// Estado local: o período do gráfico só interessa a esta tela.
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final definition = indicatorById(widget.indicatorId);
    final territory = context.watch<TerritoryController>();
    final thresholds = context.watch<SettingsController>().thresholds;
    final alerts = context.watch<AlertsController>().forIndicator(definition.id);
    final series = territory.snapshot?.series[definition.id];

    return Scaffold(
      appBar: AppBar(title: Text(definition.name)),
      body: series == null || series.history.isEmpty
          ? Center(
              child: territory.isLoading
                  ? const LoadingView()
                  : MessageView(
                      icon: Icons.cloud_off,
                      title: 'Sem dados deste indicador',
                      message: 'A fonte não respondeu e não há cópia salva.',
                      actionLabel: 'Tentar de novo',
                      onAction: territory.loadAll,
                    ),
            )
          : _content(context, definition, series, thresholds, alerts, territory),
    );
  }

  Widget _content(
    BuildContext context,
    IndicatorDefinition definition,
    IndicatorSeries series,
    Map<String, double> thresholds,
    List<TerritoryAlert> alerts,
    TerritoryController territory,
  ) {
    final threshold = thresholds[definition.id] ?? definition.defaultThreshold;
    final forecast = const Forecaster().forecast(series, territory.now);
    final history = series.history.length > _days
        ? series.history.sublist(series.history.length - _days)
        : series.history;
    final latest = series.history.last;

    return PageBody(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(territory.selected.name, style: context.text.labelLarge),
            Text(formatValue(latest.value, definition),
                style: context.text.headlineSmall),
            Text('Último dado em ${formatDay(latest.date)}'),
            const SizedBox(height: Gap.sm),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.xs,
              children: [
                OriginTag(definition.origin),
                StatusPill(
                  label: 'Tendência ${forecast.trend.label}',
                  icon: trendIcon(forecast.trend),
                  colors: context.semantic.info,
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Text(definition.description),
          ],
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 7, label: Text('7 dias')),
                    ButtonSegment(value: 30, label: Text('30 dias')),
                    ButtonSegment(value: 60, label: Text('60 dias')),
                  ],
                  selected: {_days},
                  onSelectionChanged: (value) =>
                      setState(() => _days = value.first),
                ),
                const SizedBox(height: Gap.md),
                IndicatorChart(
                  definition: definition,
                  history: history,
                  forecast: forecast.points,
                  threshold: threshold,
                ),
              ],
            ),
          ),
        ),
        _ForecastCard(forecast: forecast, definition: definition),
        Card(
          child: ListTile(
            leading: Icon(Icons.tune, color: context.colors.primary),
            title: Text('Limiar: ${formatValue(threshold, definition)}'),
            subtitle: Text(definition.direction == RiskDirection.above
                ? 'Alerta quando o valor passa deste limite.'
                : 'Alerta quando o valor fica abaixo deste limite.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.pushNamed(
              Routes.thresholds,
              queryParameters: {'indicador': definition.id},
            ),
          ),
        ),
        SectionTitle('Alertas deste indicador (${alerts.length})'),
        if (alerts.isEmpty)
          const MessageView(
            icon: Icons.task_alt,
            title: 'Nenhum alerta',
            message: 'Não há sinal de risco para este indicador agora.',
          )
        else
          for (final alert in alerts) AlertCard(alert: alert),
      ],
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.forecast, required this.definition});

  final Forecast forecast;
  final IndicatorDefinition definition;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sobre a previsão', style: context.text.titleSmall),
            const SizedBox(height: Gap.sm),
            ConfidenceMeter(forecast.confidenceAt(1)),
            const SizedBox(height: Gap.sm),
            Text('Método: ${forecast.method}.'),
            if (forecast.mape != null)
              Text('Erro médio no teste com dados passados (MAPE): '
                  '${formatPercent(forecast.mape!)}.'),
            Text('Variação recente: '
                '${formatNumber(forecast.slopePerDay, decimals: 2)} '
                '${definition.unit} por dia.'),
            if (!forecast.isReliable) ...[
              const SizedBox(height: Gap.sm),
              StatusPill(
                label: 'Previsão não confiável agora',
                icon: Icons.report_problem_outlined,
                colors: context.semantic.attention,
              ),
              const SizedBox(height: Gap.sm),
              BulletList(
                items: forecast.unreliableReasons,
                icon: Icons.chevron_right,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
