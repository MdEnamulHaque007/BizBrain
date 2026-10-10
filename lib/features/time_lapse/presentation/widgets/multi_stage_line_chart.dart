import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// A single dated value in a stage's trend series.
class TrendPoint {
  const TrendPoint({required this.date, required this.value});

  final DateTime date;
  final double value;
}

/// Multi-series line chart that plots one coloured line per production stage
/// using fl_chart. Includes an animated draw-in, per-point touch tooltips and
/// a legend below the plot.
class MultiStageLineChart extends StatelessWidget {
  const MultiStageLineChart({
    super.key,
    required this.stageData,
    required this.stageColors,
    this.showMovingAverage = false,
    this.height = 280,
  });

  /// Stage name -> its trend points (already aggregated by the caller).
  final Map<String, List<TrendPoint>> stageData;

  /// Preferred colours; series beyond the list reuse the default palette.
  final List<Color> stageColors;

  /// When true, series whose name contains `avg` are drawn as dashed lines.
  final bool showMovingAverage;

  final double height;

  static const List<Color> _palette = <Color>[
    Color(0xFF2563EB),
    Color(0xFF16A34A),
    Color(0xFFDB2777),
    Color(0xFFF59E0B),
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
    Color(0xFFDC2626),
    Color(0xFF65A30D),
  ];

  /// Deterministic colour per stage, cycling the palette for long lists.
  static List<Color> colorsFor(int count) =>
      List<Color>.generate(count, (i) => _palette[i % _palette.length]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final entries = stageData.entries
        .where((entry) => entry.value.isNotEmpty)
        .toList(growable: false);

    if (entries.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No data to plot',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final allDates = <DateTime>{};
    for (final entry in entries) {
      for (final point in entry.value) {
        allDates.add(point.date);
      }
    }
    final dates = allDates.toList()..sort();
    final indexOf = <DateTime, int>{
      for (var i = 0; i < dates.length; i++) dates[i]: i,
    };

    final fallback = colorsFor(entries.length);
    final colorOf = <String, Color>{
      for (var i = 0; i < entries.length; i++)
        entries[i].key: i < stageColors.length ? stageColors[i] : fallback[i],
    };

    final bars = <LineChartBarData>[];
    for (final entry in entries) {
      final isAvg =
          showMovingAverage && entry.key.toLowerCase().contains('avg');
      final color = colorOf[entry.key]!;
      final spots = entry.value
          .where((point) => indexOf.containsKey(point.date))
          .map((point) => FlSpot(indexOf[point.date]!.toDouble(), point.value))
          .toList(growable: false);
      bars.add(
        LineChartBarData(
          spots: spots,
          color: color,
          isCurved: !isAvg,
          curveSmoothness: 0.28,
          barWidth: isAvg ? 2 : 2.6,
          isStrokeCapRound: true,
          dashArray: isAvg ? const [6, 4] : null,
          dotData: FlDotData(show: !isAvg && dates.length <= 20),
          belowBarData: BarAreaData(
            show: !isAvg && entries.length == 1,
            color: color.withValues(alpha: 0.12),
          ),
        ),
      );
    }

    final maxY = bars
        .expand((bar) => bar.spots)
        .fold<double>(0, (acc, spot) => spot.y > acc ? spot.y : acc);
    final capY = maxY <= 0 ? 1.0 : maxY * 1.15;
    final titleStep = (dates.length / 6).ceil().clamp(1, dates.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (dates.length - 1).toDouble().clamp(0, double.infinity),
              minY: 0,
              maxY: capY,
              lineBarsData: bars,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: capY / 4,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: cs.outlineVariant, strokeWidth: 1),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  bottom: BorderSide(color: cs.outlineVariant),
                  left: BorderSide(color: cs.outlineVariant),
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 46,
                    interval: capY / 4,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(
                        _formatValue(value),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final i = value.round();
                      if (i < 0 || i >= dates.length || i % titleStep != 0) {
                        return const SizedBox.shrink();
                      }
                      final date = dates[i];
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(
                          _formatDay(date),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => cs.inverseSurface,
                  getTooltipItems: (spots) => spots.map((spot) {
                    final name = entries[spot.barIndex].key;
                    final date = dates[spot.x.round()];
                    return LineTooltipItem(
                      '${_formatDay(date)}/${date.year}\n'
                      '$name\n'
                      '${_formatValue(spot.y)}',
                      TextStyle(
                        color: cs.onInverseSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList(growable: false),
                ),
              ),
            ),
            duration: const Duration(milliseconds: 500),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            for (final entry in entries)
              _LegendItem(color: colorOf[entry.key]!, label: entry.key),
          ],
        ),
      ],
    );
  }

  static String _formatDay(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

  static String _formatValue(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
