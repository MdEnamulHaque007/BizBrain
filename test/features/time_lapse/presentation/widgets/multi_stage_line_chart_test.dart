import 'package:bizbrain/features/time_lapse/presentation/widgets/multi_stage_line_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: SizedBox(width: 400, height: 400, child: child)),
  );

  List<TrendPoint> series(List<int> values) => [
    for (var i = 0; i < values.length; i++)
      TrendPoint(
        date: DateTime(2026, 1, 1 + i),
        value: values[i].toDouble(),
      ),
  ];

  testWidgets('renders an empty-state message with no data', (tester) async {
    await tester.pumpWidget(
      host(
        const MultiStageLineChart(
          stageData: <String, List<TrendPoint>>{},
          stageColors: <Color>[],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No data to plot'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('renders a single stage line and its legend entry',
      (tester) async {
    await tester.pumpWidget(
      host(
        MultiStageLineChart(
          stageData: {'Cutting': series([10, 20, 30])},
          stageColors: MultiStageLineChart.colorsFor(1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('Cutting'), findsOneWidget);
  });

  testWidgets('renders one line per stage with all legend labels',
      (tester) async {
    await tester.pumpWidget(
      host(
        MultiStageLineChart(
          stageData: {
            'Cutting': series([10, 20, 30]),
            'Sewing': series([5, 15, 25]),
            'Finishing': series([2, 4, 6]),
          },
          stageColors: MultiStageLineChart.colorsFor(3),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('Cutting'), findsOneWidget);
    expect(find.text('Sewing'), findsOneWidget);
    expect(find.text('Finishing'), findsOneWidget);
  });

  testWidgets('ignores stages that carry no points', (tester) async {
    await tester.pumpWidget(
      host(
        MultiStageLineChart(
          stageData: {
            'Cutting': series([10, 20]),
            'Empty': const <TrendPoint>[],
          },
          stageColors: MultiStageLineChart.colorsFor(2),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cutting'), findsOneWidget);
    expect(find.text('Empty'), findsNothing);
  });
}
