import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../domain/catalog.dart';
import '../../domain/forecasting.dart';
import '../../domain/formatters.dart';
import '../../domain/models.dart';
import '../../shared/common_widgets.dart';
import '../../shared/domain_cards.dart';
import '../../shared/indicator_chart.dart';
import '../../state/settings_controller.dart';
import '../../state/territory_controller.dart';
import '../shell/app_shell.dart';

/// Três painéis com composições próprias: recursos, clima e serviços.
class DashboardsScreen extends StatefulWidget {
  const DashboardsScreen({super.key, this.initialTab});

  final String? initialTab;

  @override
  State<DashboardsScreen> createState() => _DashboardsScreenState();
}

class _DashboardsScreenState extends State<DashboardsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: DashboardKind.values.length,
    vsync: this,
    initialIndex: _indexOf(widget.initialTab),
  );

  int _indexOf(String? name) {
    final index = DashboardKind.values.indexWhere((k) => k.name == name);
    return index < 0 ? 0 : index;
  }

  @override
  void didUpdateWidget(DashboardsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      _tabs.animateTo(_indexOf(widget.initialTab));
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final territory = context.watch<TerritoryController>();
    return Scaffold(
      appBar: AppBar(
        title: Text('Painéis · ${territory.selected.name}'),
        actions: const [SettingsAction()],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            for (final kind in DashboardKind.values)
              Tab(text: kind.label, icon: Icon(dashboardIcon(kind))),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_ResourcesTab(), _ClimateTab(), _ServicesTab()],
      ),
    );
  }
}

/// Trata carregamento e erro de forma única para os três painéis.
class _TabFrame extends StatelessWidget {
  const _TabFrame({required this.builder});

  final List<Widget> Function(TerritorySnapshot snapshot) builder;

  @override
  Widget build(BuildContext context) {
    final territory = context.watch<TerritoryController>();
    final snapshot = territory.snapshot;
    return PageBody(
      onRefresh: territory.loadAll,
      children: [
        const TerritorySelector(),
        if (snapshot != null)
          ...builder(snapshot)
        else if (territory.status == LoadStatus.error)
          MessageView(
            icon: Icons.error_outline,
            title: 'Não deu para carregar',
            message: territory.errorMessage ?? 'Tente de novo.',
            actionLabel: 'Tentar de novo',
            onAction: territory.loadAll,
          )
        else
          const LoadingView(),
      ],
    );
  }
}

class _FeaturedChart extends StatelessWidget {
  const _FeaturedChart({required this.indicatorId, required this.snapshot});

  final String indicatorId;
  final TerritorySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final series = snapshot.series[indicatorId];
    if (series == null) return const SizedBox.shrink();
    final definition = indicatorById(indicatorId);
    final thresholds = context.watch<SettingsController>().thresholds;
    final now = context.read<TerritoryController>().now;
    final forecast = const Forecaster().forecast(series, now);
    final recent = series.history.length > 21
        ? series.history.sublist(series.history.length - 21)
        : series.history;
    return Card(
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
                Text(
                  '${definition.name} (${definition.unit})',
                  style: context.text.titleSmall,
                ),
                OriginTag(definition.origin),
              ],
            ),
            const SizedBox(height: Gap.md),
            IndicatorChart(
              definition: definition,
              history: recent,
              forecast: forecast.points,
              threshold: thresholds[indicatorId] ?? definition.defaultThreshold,
              height: 200,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourcesTab extends StatelessWidget {
  const _ResourcesTab();

  @override
  Widget build(BuildContext context) {
    final thresholds = context.watch<SettingsController>().thresholds;
    final now = context.read<TerritoryController>().now;
    return _TabFrame(
      builder: (snapshot) => [
        _FeaturedChart(indicatorId: 'agua', snapshot: snapshot),
        _ReservoirGauge(snapshot: snapshot, thresholds: thresholds),
        const SectionTitle('Indicadores de recursos'),
        IndicatorGrid(
          kind: DashboardKind.recursos,
          snapshot: snapshot,
          thresholds: thresholds,
          now: now,
        ),
      ],
    );
  }
}

class _ReservoirGauge extends StatelessWidget {
  const _ReservoirGauge({required this.snapshot, required this.thresholds});

  final TerritorySnapshot snapshot;
  final Map<String, double> thresholds;

  @override
  Widget build(BuildContext context) {
    final latest = snapshot.series['reservatorio']?.latest;
    if (latest == null) return const SizedBox.shrink();
    final limit = thresholds['reservatorio'] ?? 40;
    final low = latest < limit;
    final pair = low ? context.semantic.critical : context.semantic.positive;
    return Card(
      child: Semantics(
        label:
            'Reservatório local em ${formatNumber(latest)} por cento. '
            'Limiar mínimo de ${formatNumber(limit)} por cento.',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nível do reservatório', style: context.text.titleSmall),
              const SizedBox(height: Gap.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: (latest / 100).clamp(0, 1).toDouble(),
                  minHeight: 16,
                  color: pair.foreground,
                  backgroundColor: context.colors.outlineVariant,
                ),
              ),
              const SizedBox(height: Gap.sm),
              Text(
                '${formatNumber(latest)}% agora · mínimo configurado: '
                '${formatNumber(limit)}%',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClimateTab extends StatelessWidget {
  const _ClimateTab();

  @override
  Widget build(BuildContext context) {
    final territory = context.watch<TerritoryController>();
    final thresholds = context.watch<SettingsController>().thresholds;
    return _TabFrame(
      builder: (snapshot) => [
        const ConnectionBanner(),
        if (snapshot.climateUnavailable)
          MessageView(
            icon: Icons.cloud_off,
            title: 'Clima indisponível',
            message:
                'A fonte não respondeu e ainda não há dados salvos neste '
                'aparelho. Conecte-se à internet e tente de novo.',
            actionLabel: 'Tentar de novo',
            onAction: territory.loadAll,
          )
        else ...[
          _WeekStrip(snapshot: snapshot),
          _FeaturedChart(indicatorId: 'temperatura', snapshot: snapshot),
          const SectionTitle(
            'Indicadores de clima',
            subtitle: 'Fonte: Open-Meteo (dados abertos)',
          ),
          IndicatorGrid(
            kind: DashboardKind.clima,
            snapshot: snapshot,
            thresholds: thresholds,
            now: territory.now,
          ),
        ],
      ],
    );
  }
}

/// Faixa com a previsão dos próximos dias.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.snapshot});

  final TerritorySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final temperature = snapshot.series['temperatura']?.externalForecast ?? [];
    final rain = snapshot.series['chuva']?.externalForecast ?? [];
    if (temperature.isEmpty) return const SizedBox.shrink();
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Próximos dias'),
        const SizedBox(height: Gap.sm),
        SizedBox(
          height: 118 * scale,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: temperature.length,
            separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
            itemBuilder: (context, index) {
              final day = temperature[index];
              final mm = index < rain.length ? rain[index].value : 0.0;
              return SizedBox(
                width: 88 * scale,
                child: Card(
                  child: Semantics(
                    label:
                        '${formatDay(day.date)}: máxima de '
                        '${formatNumber(day.value)} graus e '
                        '${formatNumber(mm)} milímetros de chuva.',
                    excludeSemantics: true,
                    child: Padding(
                      padding: const EdgeInsets.all(Gap.sm),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            formatDay(day.date),
                            style: context.text.labelMedium,
                          ),
                          Icon(
                            mm >= 5 ? Icons.umbrella : Icons.wb_sunny_outlined,
                            color: context.colors.primary,
                          ),
                          Text(
                            '${formatNumber(day.value)}°',
                            style: context.text.titleMedium,
                          ),
                          Text(
                            '${formatNumber(mm)} mm',
                            style: context.text.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ServicesTab extends StatelessWidget {
  const _ServicesTab();

  @override
  Widget build(BuildContext context) {
    final thresholds = context.watch<SettingsController>().thresholds;
    final now = context.read<TerritoryController>().now;
    return _TabFrame(
      builder: (snapshot) => [
        const _EquityComparison(),
        _FeaturedChart(indicatorId: 'atendimentos', snapshot: snapshot),
        const SectionTitle('Indicadores de serviços'),
        IndicatorGrid(
          kind: DashboardKind.servicos,
          snapshot: snapshot,
          thresholds: thresholds,
          now: now,
        ),
      ],
    );
  }
}

/// Compara a espera entre bairros, tornando desigualdades visíveis.
class _EquityComparison extends StatelessWidget {
  const _EquityComparison();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TerritoryController>();
    final definition = indicatorById('espera');
    final rows = <(Territory, double)>[];
    for (final t in kTerritories) {
      final value = controller.snapshotOf(t.id)?.series['espera']?.latest;
      if (value != null) rows.add((t, value));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    rows.sort((a, b) => b.$2.compareTo(a.$2));
    final highest = rows.first.$2;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Espera por consulta entre bairros',
              style: context.text.titleSmall,
            ),
            const SizedBox(height: Gap.sm),
            for (final (t, value) in rows)
              Semantics(
                label: '${t.name}: ${formatValue(value, definition)}',
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: Gap.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.name,
                              style: t.id == controller.selected.id
                                  ? context.text.labelLarge
                                  : context.text.bodyMedium,
                            ),
                          ),
                          Text(formatValue(value, definition)),
                        ],
                      ),
                      const SizedBox(height: Gap.xs),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: value / highest,
                          minHeight: 8,
                          color: t.id == controller.selected.id
                              ? context.semantic.forecast
                              : context.semantic.history,
                          backgroundColor: context.colors.outlineVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
