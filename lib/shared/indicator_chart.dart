import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../domain/formatters.dart';
import '../domain/models.dart';

/// Gráfico de um indicador: histórico, previsão com faixa provável e limiar.
/// Leitores de tela recebem um resumo textual no lugar do desenho.
class IndicatorChart extends StatelessWidget {
  const IndicatorChart({
    super.key,
    required this.definition,
    required this.history,
    required this.forecast,
    required this.threshold,
    this.height = 240,
  });

  final IndicatorDefinition definition;
  final List<DataPoint> history;
  final List<ForecastPoint> forecast;
  final double threshold;
  final double height;

  List<DateTime> get _dates => [
    ...history.map((e) => e.date),
    ...forecast.map((e) => e.date),
  ];

  String get _description {
    if (history.isEmpty) return 'Gráfico sem dados de ${definition.name}.';
    final values = history.map((e) => e.value);
    final buffer = StringBuffer(
      'Gráfico de ${definition.name}, ${history.length} dias de histórico. '
      'Mínimo ${formatValue(values.reduce(min), definition)}, '
      'máximo ${formatValue(values.reduce(max), definition)}, '
      'último valor ${formatValue(history.last.value, definition)}. '
      'Limiar ${formatValue(threshold, definition)}.',
    );
    if (forecast.isNotEmpty) {
      buffer.write(
        ' Previsão para ${formatDay(forecast.last.date)}: '
        '${formatValue(forecast.last.value, definition)}.',
      );
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _description,
      image: true,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: height,
            child: definition.useBars ? _bars(context) : _lines(context),
          ),
          const SizedBox(height: Gap.sm),
          _Legend(hasForecast: forecast.isNotEmpty),
        ],
      ),
    );
  }

  (double, double) _range() {
    final values = <double>[
      threshold,
      ...history.map((e) => e.value),
      ...forecast.expand((e) => [e.value, e.lower, e.upper]),
    ];
    final low = values.reduce(min);
    final high = values.reduce(max);
    final margin = max((high - low) * 0.12, 0.5);
    final floor = low >= 0 ? max(0.0, low - margin) : low - margin;
    return (floor, high + margin);
  }

  FlTitlesData _titles(BuildContext context) {
    final dates = _dates;
    final style = context.text.labelSmall?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    final interval = max(1, (dates.length / 5).ceil()).toDouble();
    return FlTitlesData(
      topTitles: const AxisTitles(),
      rightTitles: const AxisTitles(),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 44,
          getTitlesWidget: (value, meta) {
            if (value == meta.max || value == meta.min) {
              return const SizedBox.shrink();
            }
            return Text(
              formatNumber(value, decimals: definition.decimals > 1 ? 1 : 0),
              style: style,
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 26,
          interval: interval,
          getTitlesWidget: (value, meta) {
            final index = value.round();
            // O último rótulo é sempre desenhado pela biblioteca; só os
            // múltiplos do intervalo aparecem, para as datas não se sobreporem.
            if (index < 0 ||
                index >= dates.length ||
                value != index ||
                index % interval.toInt() != 0) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: Gap.xs),
              child: Text(formatDay(dates[index]), style: style),
            );
          },
        ),
      ),
    );
  }

  FlGridData _grid(BuildContext context) => FlGridData(
    drawVerticalLine: false,
    getDrawingHorizontalLine: (_) =>
        FlLine(color: context.colors.outlineVariant, strokeWidth: 0.5),
  );

  ExtraLinesData _thresholdLine(BuildContext context) => ExtraLinesData(
    horizontalLines: [
      HorizontalLine(
        y: threshold,
        color: context.semantic.threshold,
        strokeWidth: 1.5,
        dashArray: [6, 4],
      ),
    ],
  );

  Widget _lines(BuildContext context) {
    final semantic = context.semantic;
    final (minY, maxY) = _range();
    final historySpots = [
      for (var i = 0; i < history.length; i++)
        FlSpot(i.toDouble(), history[i].value),
    ];
    final start = history.length - 1;

    double xOf(int i) => (start + 1 + i).toDouble();
    final anchor = history.isEmpty ? <FlSpot>[] : [historySpots.last];
    final forecastSpots = [
      ...anchor,
      for (var i = 0; i < forecast.length; i++)
        FlSpot(xOf(i), forecast[i].value),
    ];
    final upperSpots = [
      ...anchor,
      for (var i = 0; i < forecast.length; i++)
        FlSpot(xOf(i), forecast[i].upper),
    ];
    final lowerSpots = [
      ...anchor,
      for (var i = 0; i < forecast.length; i++)
        FlSpot(xOf(i), max(forecast[i].lower, minY)),
    ];

    LineChartBarData invisible(List<FlSpot> spots) => LineChartBarData(
      spots: spots,
      color: Colors.transparent,
      barWidth: 0,
      dotData: const FlDotData(show: false),
    );

    final hasForecast = forecast.isNotEmpty && history.isNotEmpty;
    final bars = <LineChartBarData>[
      LineChartBarData(
        spots: historySpots,
        color: semantic.history,
        barWidth: 2.5,
        isCurved: true,
        curveSmoothness: 0.15,
        preventCurveOverShooting: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: semantic.history.withValues(alpha: 0.08),
        ),
      ),
      if (hasForecast) ...[
        invisible(upperSpots),
        invisible(lowerSpots),
        LineChartBarData(
          spots: forecastSpots,
          color: semantic.forecast,
          barWidth: 2.5,
          dashArray: [5, 4],
          dotData: const FlDotData(show: false),
        ),
      ],
    ];

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: _grid(context),
        borderData: FlBorderData(show: false),
        titlesData: _titles(context),
        extraLinesData: _thresholdLine(context),
        lineBarsData: bars,
        betweenBarsData: [
          if (hasForecast)
            BetweenBarsData(
              fromIndex: 1,
              toIndex: 2,
              color: semantic.forecast.withValues(alpha: 0.16),
            ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => context.colors.inverseSurface,
            getTooltipItems: (touched) => [
              for (final spot in touched)
                spot.barIndex == 1 || spot.barIndex == 2
                    ? null
                    : LineTooltipItem(
                        '${formatDay(_dates[spot.x.round()])}\n'
                        '${formatValue(spot.y, definition)}',
                        TextStyle(
                          color: context.colors.onInverseSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bars(BuildContext context) {
    final semantic = context.semantic;
    final (_, maxY) = _range();
    final count = history.length + forecast.length;
    final width = count > 40 ? 3.0 : (count > 20 ? 6.0 : 12.0);

    BarChartGroupData group(int x, double value, Color color) =>
        BarChartGroupData(
          x: x,
          barRods: [
            BarChartRodData(
              toY: value,
              color: color,
              width: width,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(3),
              ),
            ),
          ],
        );

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY,
        gridData: _grid(context),
        borderData: FlBorderData(show: false),
        titlesData: _titles(context),
        extraLinesData: _thresholdLine(context),
        barGroups: [
          for (var i = 0; i < history.length; i++)
            group(i, history[i].value, semantic.history),
          for (var i = 0; i < forecast.length; i++)
            group(history.length + i, forecast[i].value, semantic.forecast),
        ],
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => context.colors.inverseSurface,
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              '${formatDay(_dates[group.x])}\n'
              '${formatValue(rod.toY, definition)}',
              TextStyle(
                color: context.colors.onInverseSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.hasForecast});

  final bool hasForecast;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    return Wrap(
      spacing: Gap.md,
      runSpacing: Gap.xs,
      children: [
        _item(context, semantic.history, 'Histórico'),
        if (hasForecast) _item(context, semantic.forecast, 'Previsão'),
        _item(context, semantic.threshold, 'Limiar'),
      ],
    );
  }

  Widget _item(BuildContext context, Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 16, height: 4, color: color),
      const SizedBox(width: Gap.xs),
      Text(label, style: context.text.labelSmall),
    ],
  );
}

/// Minigráfico de tendência para os cartões. É decorativo: o cartão já informa
/// valor e tendência em texto.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < values.length; i++)
                  FlSpot(i.toDouble(), values[i]),
              ],
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
