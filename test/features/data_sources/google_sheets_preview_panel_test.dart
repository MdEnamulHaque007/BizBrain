import 'package:bizbrain/features/data_sources/data/google_sheets/google_sheets_loader.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_manager.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_storage.dart';
import 'package:bizbrain/features/data_sources/data/repositories/cached_data_source_repository.dart';
import 'package:bizbrain/features/data_sources/presentation/providers/google_sheets_providers.dart';
import 'package:bizbrain/features/data_sources/presentation/widgets/google_sheets_preview_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('automatically displays the newest cached sheet on open', (
    tester,
  ) async {
    final latest = _cache(
      sourceId: 'abcdefghijk|Inventory|A1:B20|1',
      sheetName: 'Inventory',
      fetchedAt: DateTime.now(),
    );
    final manager = SheetCacheManager(_TestCacheStorage(latest));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sheetCacheStorageReadyProvider.overrideWith((ref) => true),
          cachedSourcesProvider.overrideWith((ref) async => [latest]),
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

    expect(find.text('Cached sheets'), findsOneWidget);
    expect(find.text('Inventory'), findsWidgets);
    expect(find.text('Boot'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });

  testWidgets('Connect loads and immediately displays sheet data', (
    tester,
  ) async {
    final storage = _TestCacheStorage(null);
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
          cachedSourcesProvider.overrideWith((ref) async => []),
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
    await tester.enterText(find.byType(TextField).first, 'abcdefghijk');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(find.text('Boot'), findsOneWidget);
    expect(requestCount, 1);

    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(requestCount, 1);
  });
}

SheetCacheModel _cache({
  required String sourceId,
  required String sheetName,
  required DateTime fetchedAt,
}) => SheetCacheModel(
  sourceId: sourceId,
  organizationId: 'default',
  sheetUrl: 'https://docs.google.com/spreadsheets/d/abcdefghijk/gviz/tq',
  sheetName: sheetName,
  rows: const [
    {'Name': 'Boot', 'Qty': '4'},
  ],
  columns: const ['Name', 'Qty'],
  fetchedAt: fetchedAt,
  rowCount: 1,
  version: 1,
);

class _TestCacheStorage implements SheetCacheStorage {
  _TestCacheStorage(SheetCacheModel? cache)
    : _values = cache == null ? {} : {cache.sourceId: cache};

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
