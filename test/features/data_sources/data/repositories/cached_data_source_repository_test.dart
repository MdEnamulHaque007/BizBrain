import 'package:bizbrain/features/data_sources/data/google_sheets/google_sheets_loader.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_manager.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_storage.dart';
import 'package:bizbrain/features/data_sources/data/repositories/cached_data_source_repository.dart';
import 'package:bizbrain/features/data_sources/domain/entities/google_sheets_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late _MemoryStorage storage;
  late CachedDataSourceRepository repository;
  late int requestCount;
  final source = GoogleSheetsDataSource.parse(input: 'abcdefghijk');

  setUp(() {
    requestCount = 0;
    storage = _MemoryStorage();
    repository = CachedDataSourceRepository(
      loader: GoogleSheetsLoader(
        client: MockClient((_) async {
          requestCount++;
          return http.Response('Name,Qty\nBoot,4\n', 200);
        }),
        clock: () => DateTime.utc(2026, 10, 8),
      ),
      cache: SheetCacheManager(storage),
    );
  });

  test(
    'cache miss fetches and saves; cache hit does not fetch again',
    () async {
      final fresh = await repository.loadDataSource(
        source: source,
        sourceId: 'source-one',
        organizationId: 'org-one',
        sourceLabel: 'Inventory',
        sourceInput: 'abcdefghijk',
      );

      expect(fresh.rows, [
        {'Name': 'Boot', 'Qty': '4'},
      ]);
      expect(fresh.sourceLabel, 'Inventory');
      expect(fresh.sourceInput, 'abcdefghijk');
      expect(requestCount, 1);
      expect(
        await repository.loadDataSource(
          source: source,
          sourceId: 'source-one',
          organizationId: 'org-one',
          sourceLabel: 'Inventory',
          sourceInput: 'abcdefghijk',
        ),
        fresh,
      );
      expect(requestCount, 1);
    },
  );

  test('refresh fetches new data and delete removes local cache', () async {
    await repository.refreshDataSource(
      source: source,
      sourceId: 'source-one',
      organizationId: 'org-one',
      sourceLabel: 'Inventory',
      sourceInput: 'abcdefghijk',
    );
    expect(requestCount, 1);
    await repository.refreshDataSource(
      source: source,
      sourceId: 'source-one',
      organizationId: 'org-one',
      sourceLabel: 'Inventory',
      sourceInput: 'abcdefghijk',
    );
    expect(requestCount, 2);

    await repository.deleteDataSource('source-one');

    expect(await storage.get('source-one'), isNull);
    expect(await storage.getAll(organizationId: 'org-one'), isEmpty);
    expect(requestCount, 2);
  });

  test('cache hit without a label preserves the saved label', () async {
    await repository.loadDataSource(
      source: source,
      sourceId: 'source-one',
      organizationId: 'org-one',
      sourceLabel: 'Inventory',
      sourceInput: 'abcdefghijk',
    );
    expect(requestCount, 1);

    final reloaded = await repository.loadDataSource(
      source: source,
      sourceId: 'source-one',
      organizationId: 'org-one',
      // No explicit label: the previously saved label must survive.
      sourceInput: 'abcdefghijk',
    );

    expect(requestCount, 1);
    expect(reloaded.sourceLabel, 'Inventory');
  });

  test('cache hit with an explicit label overwrites it', () async {
    await repository.loadDataSource(
      source: source,
      sourceId: 'source-one',
      organizationId: 'org-one',
      sourceLabel: 'Old label',
      sourceInput: 'abcdefghijk',
    );

    final reloaded = await repository.loadDataSource(
      source: source,
      sourceId: 'source-one',
      organizationId: 'org-one',
      sourceLabel: 'New label',
      sourceInput: 'abcdefghijk',
    );

    expect(reloaded.sourceLabel, 'New label');
  });

  test(
    'loads and migrates caches saved with the previous source ID format',
    () async {
      final legacy = createCache('abcdefghijk|||h1', 'org-one');
      await storage.save(legacy);

      final loaded = await repository.loadDataSource(
        source: source,
        sourceId: 'abcdefghijk|||1',
        organizationId: 'org-one',
      );

      expect(loaded.sourceId, 'abcdefghijk|||1');
      expect(await storage.get(legacy.sourceId), isNull);
      expect(requestCount, 0);
    },
  );
}

SheetCacheModel createCache(String id, String organizationId) =>
    SheetCacheModel(
      sourceId: id,
      organizationId: organizationId,
      sheetUrl: 'url',
      sheetName: id,
      rows: const [],
      columns: const [],
      fetchedAt: DateTime.utc(2026, 10, 8),
      rowCount: 0,
      version: 1,
    );

class _MemoryStorage implements SheetCacheStorage {
  final Map<String, SheetCacheModel> values = {};

  @override
  Future<void> save(SheetCacheModel cache) async {
    values[cache.sourceId] = cache;
  }

  @override
  Future<SheetCacheModel?> get(String sourceId) async => values[sourceId];

  @override
  Future<List<SheetCacheModel>> getAll({String? organizationId}) async => values
      .values
      .where(
        (cache) =>
            organizationId == null || cache.organizationId == organizationId,
      )
      .toList();

  @override
  Future<void> delete(String sourceId) async {
    values.remove(sourceId);
  }

  @override
  Future<void> clearAll({String? organizationId}) async {
    if (organizationId == null) {
      values.clear();
    } else {
      values.removeWhere((_, cache) => cache.organizationId == organizationId);
    }
  }

  @override
  Future<bool> exists(String sourceId) async => values.containsKey(sourceId);

  @override
  Future<DateTime?> getLastFetchTime(String sourceId) async =>
      values[sourceId]?.fetchedAt;

  @override
  Stream<SheetCacheModel?> watch(String sourceId) async* {
    yield values[sourceId];
  }
}
