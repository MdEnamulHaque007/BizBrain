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
      );

      expect(fresh.rows, [
        {'Name': 'Boot', 'Qty': '4'},
      ]);
      expect(requestCount, 1);
      expect(
        await repository.loadDataSource(
          source: source,
          sourceId: 'source-one',
          organizationId: 'org-one',
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
    );
    expect(requestCount, 1);
    await repository.refreshDataSource(
      source: source,
      sourceId: 'source-one',
      organizationId: 'org-one',
    );
    expect(requestCount, 2);

    await repository.deleteDataSource('source-one');

    expect(await repository.getDataSource('source-one'), isNull);
    expect(
      await repository.listDataSources(organizationId: 'org-one'),
      isEmpty,
    );
    expect(requestCount, 2);
  });

  test('organization stream yields only that organization’s cache', () async {
    await storage.save(createCache('one', 'org-one'));
    await storage.save(createCache('two', 'org-two'));

    final sources = await repository.watchForOrganization('org-one').first;

    expect(sources.map((source) => source.id), ['one']);
  });
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
