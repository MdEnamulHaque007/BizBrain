import 'package:bizbrain/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the application entry point starts safely', (tester) async {
    // No overrides: the application must boot with its built-in safest
    // defaults (Firebase unconfigured, authentication backend unavailable)
    // without throwing.
    await tester.pumpWidget(const ProviderScope(child: BizBrainApp()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(BizBrainApp), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'BizBrain AI');
  });
}
