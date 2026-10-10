import 'package:bizbrain/features/data_sources/data/google_sheets/google_sheets_loader.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_manager.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_storage.dart';
import 'package:bizbrain/features/data_sources/data/repositories/cached_data_source_repository.dart';
import 'package:bizbrain/features/data_sources/presentation/providers/google_sheets_providers.dart';
import 'package:bizbrain/features/data_sources/presentation/widgets/google_sheets_preview_panel.dart';
import 'package:bizbrain/features/organizations/domain/entities/organization.dart';
import 'package:bizbrain/features/organizations/presentation/providers/organization_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final DateTime _testOrgCreatedAt = DateTime.utc(2026, 1, 1);

final Organization _testOrg = Organization(
  id: 'org-1',
  name: 'Acme',
  ownerId: 'u-1',
  memberIds: ['u-1'],
  status: OrganizationStatus.active,
  createdAt: _testOrgCreatedAt,
);

void main() {
  testWidgets('automatically displays the newest cached sheet on open', (
    tester,
  ) async {
    final latest = _cache(
      sourceId: 'abcdefghijk|Inventory|A1:B20|1',
      sheetName: 'Inventory',
      fetchedAt: DateTime.now(),
    );
    final second = _cache(
      sourceId: 'lmnopqrstuv|Orders||1',
      sheetName: 'Orders',
      fetchedAt: DateTime.now().subtract(const Duration(hours: 1)),
      rowText: 'Order item',
    );
    final manager = SheetCacheManager(_TestCacheStorage([latest, second]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sheetCacheStorageReadyProvider.overrideWith((ref) => true),
          activeOrganizationProvider.overrideWithValue(_testOrg),
          sourcesListProvider('org-1').overrideWith((ref) async => [
            latest,
            second,
          ]),
          sheetCacheManagerProvider.overrideWith((ref) => manager),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: GoogleSheetsPreviewPanel()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved Google Sheets (2)'), findsOneWidget);
    expect(find.text('Inventory'), findsWidgets);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Boot'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);

    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();
    expect(find.text('Order item'), findsOneWidget);
    expect(find.text('Editing'), findsOneWidget);
    expect(find.text('Cancel Edit'), findsOneWidget);

    await tester.ensureVisible(find.text('Cancel Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Editing'), findsNothing);
    expect(find.text('Cancel Edit'), findsNothing);
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .first
          .controller!
          .text,
      '',
    );
  });

  testWidgets('Connect loads and immediately displays sheet data', (
    tester,
  ) async {
    final storage = _TestCacheStorage([]);
    final manager = SheetCacheManager(storage);
    var requestCount = 0;
    final repository = CachedDataSourceRepository(
      loader: GoogleSheetsLoader(
        client: MockClient((_) async {
          requestCount++;
          return http.Response('Name,Qty\nBoot,4\n', 200);
        }),
      ),
      cache: manager,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sheetCacheStorageReadyProvider.overrideWith((ref) => true),
          activeOrganizationProvider.overrideWithValue(_testOrg),
          sourcesListProvider('org-1').overrideWith((ref) async => []),
          sheetCacheManagerProvider.overrideWith((ref) => manager),
          cachedDataSourceRepositoryProvider.overrideWith((ref) => repository),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: GoogleSheetsPreviewPanel()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'abcdefghijk');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(find.text('Boot'), findsOneWidget);
    expect(requestCount, 1);

    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(requestCount, 1);
  });

  testWidgets('Add New Sheet clears fields and focuses the URL input', (
    tester,
  ) async {
    final manager = SheetCacheManager(_TestCacheStorage([]));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sheetCacheStorageReadyProvider.overrideWith((ref) => true),
          activeOrganizationProvider.overrideWithValue(_testOrg),
          sourcesListProvider('org-1').overrideWith((ref) async => []),
          sheetCacheManagerProvider.overrideWith((ref) => manager),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: GoogleSheetsPreviewPanel()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Old label');
    await tester.enterText(fields.at(1), 'abcdefghijk');
    await tester.enterText(fields.at(2), 'Old tab');
    await tester.enterText(fields.at(3), 'A1:B10');
    await tester.enterText(fields.at(4), '3');
    await tester.tap(find.text('Add New Sheet'));
    await tester.pumpAndSettle();

    final clearedFields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(clearedFields[0].controller!.text, isEmpty);
    expect(clearedFields[1].controller!.text, isEmpty);
    expect(clearedFields[2].controller!.text, isEmpty);
    expect(clearedFields[3].controller!.text, isEmpty);
    expect(clearedFields[4].controller!.text, '1');
    expect(clearedFields[1].focusNode!.hasFocus, isTrue);
  });
}

SheetCacheModel _cache({
  required String sourceId,
  required String sheetName,
  required DateTime fetchedAt,
  String rowText = 'Boot',
}) => SheetCacheModel(
  sourceId: sourceId,
  organizationId: 'org-1',
  sheetUrl: 'https://docs.google.com/spreadsheets/d/abcdefghijk/gviz/tq',
  sheetName: sheetName,
  rows: [
    {'Name': rowText, 'Qty': '4'},
  ],
  columns: const ['Name', 'Qty'],
  fetchedAt: fetchedAt,
  rowCount: 1,
  version: 1,
);

class _TestCacheStorage implements SheetCacheStorage {
  _TestCacheStorage(List<SheetCacheModel> caches)
    : _values = {for (final cache in caches) cache.sourceId: cache};

  final Map<String, SheetCacheModel> _values;

  @override
  Future<void> save(SheetCacheModel cache) async {
    _values[cache.sourceId] = cache;
  }

  @override
  Future<SheetCacheModel?> get(String sourceId) async => _values[sourceId];

  @override
  Future<List<SheetCacheModel>> getAll({String? organizationId}) async =>
      _values.values
          .where(
            (cache) =>
                organizationId == null ||
                cache.organizationId == organizationId,
          )
          .toList();

  @override
  Future<void> delete(String sourceId) async {
    _values.remove(sourceId);
  }

  @override
  Future<void> clearAll({String? organizationId}) async {
    if (organizationId == null) {
      _values.clear();
    } else {
      _values.removeWhere((_, cache) => cache.organizationId == organizationId);
    }
  }

  @override
  Future<bool> exists(String sourceId) async => _values.containsKey(sourceId);

  @override
  Future<DateTime?> getLastFetchTime(String sourceId) async =>
      _values[sourceId]?.fetchedAt;

  @override
  Stream<SheetCacheModel?> watch(String sourceId) async* {
    yield _values[sourceId];
  }
}
