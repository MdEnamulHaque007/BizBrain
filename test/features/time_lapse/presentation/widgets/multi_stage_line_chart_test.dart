import 'package:bizbrain/features/time_lapse/presentation/widgets/multi_stage_line_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: SizedBox(width: 400, height: 400, child: child)),
  );

  StageSeries stage(String name, Color color, List<int> values) => StageSeries(
    stageName: name,
    color: color,
    points: [
      for (var i = 0; i < values.length; i++)
        TrendPoint(date: DateTime(2026, 1, 1 + i), value: values[i].toDouble()),
    ],
  );

  List<LineChartBarData> barsOf(WidgetTester tester) =>
      (tester.widget<LineChart>(find.byType(LineChart)).data).lineBarsData;

  testWidgets('empty series shows the empty state and no chart',
      (tester) async {
    await tester.pumpWidget(
      host(const MultiStageLineChart(series: <StageSeries>[])),
    );
    await tester.pumpAndSettle();

    expect(find.text('No matching date and quantity rows'), findsOneWidget);
    expect(find.byIcon(Icons.query_stats_rounded), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('single stage renders one chart with one bar and its legend',
      (tester) async {
    await tester.pumpWidget(
      host(
        MultiStageLineChart(
          series: [
            stage('Cutting', MultiStageLineChart.colorFor(0), [10, 20, 30]),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LineChart), findsOneWidget);
    expect(barsOf(tester), hasLength(1));
    expect(find.text('Cutting'), findsOneWidget);
  });

  testWidgets('multiple stages render one bar each with all legend labels',
      (tester) async {
    await tester.pumpWidget(
      host(
        MultiStageLineChart(
          series: [
            stage('Cutting', MultiStageLineChart.colorFor(0), [10, 20, 30]),
            stage('Sewing', MultiStageLineChart.colorFor(1), [5, 15, 25]),
            stage('Production', MultiStageLineChart.colorFor(2), [2, 4, 6]),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LineChart), findsOneWidget);
    expect(barsOf(tester), hasLength(3));
    expect(find.text('Cutting'), findsOneWidget);
    expect(find.text('Sewing'), findsOneWidget);
    expect(find.text('Production'), findsOneWidget);
  });

  testWidgets('moving average toggle adds a dashed 7-day avg bar and legend',
      (tester) async {
    await tester.pumpWidget(
      host(
        MultiStageLineChart(
          series: [
            stage('Cutting', MultiStageLineChart.colorFor(0), [10, 20, 30]),
          ],
          showMovingAverage: true,
          movingAverageSeries: [
            TrendPoint(date: DateTime(2026, 1, 3), value: 20),
            TrendPoint(date: DateTime(2026, 1, 4), value: 25),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bars = barsOf(tester);
    expect(bars, hasLength(2));
    expect(bars.last.dashArray, isNotNull);
    expect(find.text('7-day avg'), findsOneWidget);
  });

  testWidgets('chart respects the height parameter', (tester) async {
    await tester.pumpWidget(
      host(
        MultiStageLineChart(
          series: [
            stage('Cutting', MultiStageLineChart.colorFor(0), [10, 20, 30]),
          ],
          height: 200,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final box = tester.renderObject<RenderBox>(
      find
          .ancestor(
            of: find.byType(LineChart),
            matching: find.byType(SizedBox),
          )
          .first,
    );
    expect(box.size.height, 200);
  });

  testWidgets('colors are assigned from the palette by index',
      (tester) async {
    await tester.pumpWidget(
      host(
        MultiStageLineChart(
          series: [
            stage('Cutting', MultiStageLineChart.colorFor(0), [10, 20]),
            stage('Sewing', MultiStageLineChart.colorFor(1), [5, 15]),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bars = barsOf(tester);
    expect(bars[0].color, MultiStageLineChart.colorFor(0));
    expect(bars[1].color, MultiStageLineChart.colorFor(1));
    expect(colorsOf(0) != colorsOf(1), isTrue);
  });
}

Color colorsOf(int index) => MultiStageLineChart.colorFor(index);