import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// A single dated value in a stage's trend series.
class TrendPoint {
  const TrendPoint({required this.date, required this.value});

  final DateTime date;
  final double value;
}

/// One coloured production stage plotted in [MultiStageLineChart].
class StageSeries {
  const StageSeries({
    required this.stageName,
    required this.color,
    required this.points,
  });

  final String stageName;
  final Color color;
  final List<TrendPoint> points;
}

/// Multi-series line chart that plots one coloured line per production stage
/// using fl_chart. Includes an animated draw-in, per-point touch tooltips, a
/// dashed 7-day moving average overlay and a legend below the plot.
class MultiStageLineChart extends StatelessWidget {
  const MultiStageLineChart({
    super.key,
    required this.series,
    this.showMovingAverage = false,
    this.movingAverageSeries,
    this.height = 250,
  });

  final List<StageSeries> series;
  final bool showMovingAverage;

  /// Optional precomputed 7-day average trend, drawn dashed in grey.
  final List<TrendPoint>? movingAverageSeries;

  final double height;

  static const List<Color> _palette = <Color>[
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
  ];

  /// Deterministic colour per index, cycling the palette for long lists.
  static Color colorFor(int index) => _palette[index % _palette.length];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final populated = series
        .where((s) => s.points.isNotEmpty)
        .toList(growable: false);

    if (populated.isEmpty) {
      return _emptyState(context);
    }

    final allDates = <DateTime>{};
    for (final entry in populated) {
      for (final point in entry.points) {
        allDates.add(point.date);
      }
    }
    final dates = allDates.toList()..sort();
    final indexOf = <DateTime, int>{
      for (var i = 0; i < dates.length; i++) dates[i]: i,
    };

    final bars = <LineChartBarData>[];
    for (final entry in populated) {
      final spots = entry.points
          .where((point) => indexOf.containsKey(point.date))
          .map((point) => FlSpot(indexOf[point.date]!.toDouble(), point.value))
          .toList(growable: false);
      bars.add(
        LineChartBarData(
          spots: spots,
          color: entry.color,
          isCurved: true,
          curveSmoothness: 0.3,
          barWidth: 2.8,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: dates.length <= 20,
            getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
              radius: 3.5,
              color: entry.color,
              strokeWidth: 0,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            color: entry.color.withValues(alpha: 0.12),
          ),
        ),
      );
    }

    final avg = showMovingAverage ? movingAverageSeries : const <TrendPoint>[];
    if (showMovingAverage && (avg == null || avg.isEmpty)) {
      bars.add(
        LineChartBarData(
          spots: const <FlSpot>[],
          color: Colors.grey,
          isCurved: true,
          curveSmoothness: 0.3,
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
      );
    } else if (showMovingAverage && avg != null) {
      bars.add(
        LineChartBarData(
          spots: avg
              .where((point) => indexOf.containsKey(point.date))
              .map(
                (point) =>
                    FlSpot(indexOf[point.date]!.toDouble(), point.value),
              )
              .toList(growable: false),
          color: Colors.grey.shade600,
          isCurved: true,
          curveSmoothness: 0.3,
          barWidth: 2,
          dashArray: const <int>[6, 4],
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    final maxY = bars
        .expand((bar) => bar.spots)
        .fold<double>(0, (acc, spot) => spot.y > acc ? spot.y : acc);
    final capY = maxY <= 0 ? 1.0 : maxY * 1.12;
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
                    final safeIndex = spot.barIndex.clamp(
                      0,
                      populated.length - 1,
                    );
                    final name = populated[safeIndex].stageName;
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
            for (final entry in populated)
              _LegendItem(
                color: entry.color,
                label: entry.stageName,
                dashed: false,
              ),
            if (showMovingAverage)
              _LegendItem(
                color: Colors.grey.shade600,
                label: '7-day avg',
                dashed: true,
              ),
          ],
        ),
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.query_stats_rounded, size: 42, color: cs.tertiary),
          const SizedBox(height: 12),
          Text(
            'No matching date and quantity rows',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Check the selected headers or choose All dates. Only real '
            'numeric quantities with readable dates are plotted.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
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
  const _LegendItem({
    required this.color,
    required this.label,
    required this.dashed,
  });

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dashed
            ? CustomPaint(
                size: const Size(16, 4),
                painter: _DashPainter(color),
              )
            : Container(
                width: 16,
                height: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, size.height / 2), Offset(x + 7, size.height / 2), paint);
      x += 10;
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter oldDelegate) =>
      oldDelegate.color != color;
}