import 'package:bizbrain/features/ai_brain/presentation/screens/ai_brain_screen.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';
import 'package:bizbrain/features/data_sources/presentation/providers/google_sheets_providers.dart';
import 'package:bizbrain/features/organizations/domain/entities/organization.dart';
import 'package:bizbrain/features/organizations/presentation/providers/organization_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final Organization _testOrg = Organization(
  id: 'org-1',
  name: 'Acme',
  ownerId: 'u-test',
  memberIds: ['u-test'],
  status: OrganizationStatus.active,
  createdAt: DateTime.utc(2026, 1, 1),
);

void main() {
  testWidgets('mapped table renders PO quantity and Date columns',
      (tester) async {
    final source = SheetCacheModel(
      sourceId: 'abcd|PO|A1:F2|1',
      organizationId: 'org-1',
      sheetUrl: 'https://docs.google.com/spreadsheets/d/abcd/gviz/tq',
      sheetName: 'PO',
      sourceLabel: 'PO',
      rows: const [
        {
          'PO No': 'PO 001',
          'Article': 'Boot',
          'Color': 'Black',
          'PO Qty': '100',
          'Date': '24/05/2026',
        },
      ],
      columns: const ['PO No', 'Article', 'Color', 'PO Qty', 'Date'],
      fetchedAt: DateTime.utc(2026, 6, 1),
      rowCount: 1,
      version: 1,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sheetCacheStorageReadyProvider.overrideWith((ref) => true),
          activeOrganizationProvider.overrideWithValue(_testOrg),
          sourcesListProvider('org-1').overrideWith((ref) async => [source]),
        ],
        child: const MaterialApp(home: AiBrainScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Date'), findsOneWidget);
    expect(find.text('24/05/2026'), findsOneWidget);
    expect(find.text('PO 001'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
  });

  testWidgets('empty date renders a placeholder dash', (tester) async {
    final source = SheetCacheModel(
      sourceId: 'abcd|PO|A1:F2|1',
      organizationId: 'org-1',
      sheetUrl: 'https://docs.google.com/spreadsheets/d/abcd/gviz/tq',
      sheetName: 'PO',
      sourceLabel: 'PO',
      rows: const [
        {'PO No': 'PO 001', 'Article': 'Boot', 'Color': 'Black', 'Qty': '100'},
      ],
      columns: const ['PO No', 'Article', 'Color', 'Qty'],
      fetchedAt: DateTime.utc(2026, 6, 1),
      rowCount: 1,
      version: 1,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sheetCacheStorageReadyProvider.overrideWith((ref) => true),
          activeOrganizationProvider.overrideWithValue(_testOrg),
          sourcesListProvider('org-1').overrideWith((ref) async => [source]),
        ],
        child: const MaterialApp(home: AiBrainScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('—'), findsOneWidget);
  });
}