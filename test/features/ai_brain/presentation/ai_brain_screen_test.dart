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
  testWidgets('mapped table shows all quantity columns and no Date',
      (tester) async {
    final po = SheetCacheModel(
      sourceId: 'abcd|PO|A1:F2|1',
      organizationId: 'org-1',
      sheetUrl: 'https://docs.google.com/spreadsheets/d/abcd/gviz/tq',
      sheetName: 'PO',
      sourceLabel: 'PO',
      rows: const [
        {'PO No': 'PO 001', 'Article': 'Boot', 'Color': 'Black', 'PO Qty': '100'},
      ],
      columns: const ['PO No', 'Article', 'Color', 'PO Qty'],
      fetchedAt: DateTime.utc(2026, 6, 1),
      rowCount: 1,
      version: 1,
    );
    final stock = SheetCacheModel(
      sourceId: 'efgh|Stock|A1:F2|1',
      organizationId: 'org-1',
      sheetUrl: 'https://docs.google.com/spreadsheets/d/efgh/gviz/tq',
      sheetName: 'Stock',
      sourceLabel: 'Stock',
      rows: const [
        {'PO No': 'PO 001', 'Article': 'Boot', 'Color': 'Black', 'Stock': '40'},
      ],
      columns: const ['PO No', 'Article', 'Color', 'Stock'],
      fetchedAt: DateTime.utc(2026, 6, 1),
      rowCount: 1,
      version: 1,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sheetCacheStorageReadyProvider.overrideWith((ref) => true),
          activeOrganizationProvider.overrideWithValue(_testOrg),
          sourcesListProvider('org-1').overrideWith((ref) async => [po, stock]),
        ],
        child: const MaterialApp(home: AiBrainScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PO No'), findsOneWidget);
    expect(find.text('Article'), findsOneWidget);
    expect(find.text('Color'), findsOneWidget);
    expect(find.text('PO'), findsOneWidget);
    expect(find.text('Cutting'), findsOneWidget);
    expect(find.text('Sewing'), findsOneWidget);
    expect(find.text('Lasting'), findsOneWidget);
    expect(find.text('FG'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
    expect(find.text('Stock'), findsWidgets);
    expect(find.text('Date'), findsNothing);

    expect(find.text('PO 001'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
  });
}