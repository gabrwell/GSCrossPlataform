import 'models.dart';

String _two(int value) => value.toString().padLeft(2, '0');

String formatDay(DateTime date) => '${_two(date.day)}/${_two(date.month)}';

String formatDateTime(DateTime date) =>
    '${formatDay(date)} às ${_two(date.hour)}:${_two(date.minute)}';

String compactDay(DateTime date) =>
    '${date.year}${_two(date.month)}${_two(date.day)}';

String formatNumber(double value, {int decimals = 0}) =>
    value.toStringAsFixed(decimals).replaceAll('.', ',');

String formatValue(double value, IndicatorDefinition definition) =>
    '${formatNumber(value, decimals: definition.decimals)} ${definition.unit}';

String formatPercent(double ratio) => '${(ratio * 100).toStringAsFixed(0)}%';

/// 275000 vira "275 mil"; 1200000 vira "1,2 milhão".
String formatCompact(double value) {
  if (value >= 2000000) {
    return '${formatNumber(value / 1000000, decimals: 1)} milhões';
  }
  if (value >= 1000000) {
    return '${formatNumber(value / 1000000, decimals: 1)} milhão';
  }
  if (value >= 1000) return '${formatNumber(value / 1000)} mil';
  return formatNumber(value);
}
