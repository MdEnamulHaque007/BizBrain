import 'dart:convert';

import 'package:bizbrain/features/data_sources/data/local/sheet_cache_manager.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _MemoryStorage storage;
  late SheetCacheManager manager;

  setUp(() {
    storage = _MemoryStorage();
    manager = SheetCacheManager(
      storage,
      defaultStaleThreshold: const Duration(days: 7),
      maxCacheSizeBytes: 100000,
    );
  });

  test('detects stale cache using configured threshold', () {
    expect(manager.isStale(createCache('old', DateTime.utc(2026, 1))), isTrue);
    expect(manager.isStale(createCache('new', DateTime.now())), isFalse);
  });

  test('saves, retrieves, ages, and invalidates a cache', () async {
    final cache = createCache('one', DateTime.now());
    await manager.saveCache(cache);

    expect(await manager.getCached('one'), cache);
    expect(await manager.getCacheAge('one'), isNotNull);
    await manager.invalidate('one');
    expect(await manager.getCached('one'), isNull);
  });

  test('enforces byte limit by evicting oldest entries', () async {
    final newest = createCache('new', DateTime.utc(2026, 2));
    final limit = utf8.encode(jsonEncode(newest.toJson())).length;
    manager = SheetCacheManager(storage, maxCacheSizeBytes: limit);
    await manager.saveCache(createCache('old', DateTime.utc(2026, 1)));
    await manager.saveCache(newest);

    expect(await manager.getCached('old'), isNull);
    expect(await manager.getCached('new'), newest);
  });

  test('invalidates only the requested organization', () async {
    await storage.save(createCache('a', DateTime.now(), organizationId: 'a'));
    await storage.save(createCache('b', DateTime.now(), organizationId: 'b'));

    await manager.invalidateAll(organizationId: 'a');

    expect(await manager.getCached('a'), isNull);
    expect(await manager.getCached('b'), isNotNull);
  });
}

SheetCacheModel createCache(
  String id,
  DateTime fetchedAt, {
  String organizationId = 'org',
}) => SheetCacheModel(
  sourceId: id,
  organizationId: organizationId,
  sheetUrl: 'url',
  sheetName: 'Sheet',
  rows: List.generate(3, (index) => {'value': '$index'}),
  columns: const ['value'],
  fetchedAt: fetchedAt,
  rowCount: 3,
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
