import 'dart:io';

import 'package:bizbrain/features/data_sources/data/local/sheet_cache_manager.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_storage.dart';
import 'package:bizbrain/features/data_sources/presentation/providers/google_sheets_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  final now = DateTime.utc(2026, 1, 8);
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('bizbrain_org_scope_');
    Hive.init(directory.path);
    Hive.registerAdapter(SheetCacheModelAdapter());
    // `sourcesListProvider` only consults the manager once Hive reports the
    // cache box as open; open a throwaway box to satisfy that gate while the
    // storage itself is overridden below.
    await Hive.openBox<SheetCacheModel>('sheet_cache_v1');
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  SheetCacheModel cache(String id, String org, DateTime fetchedAt) =>
      SheetCacheModel(
        sourceId: id,
        organizationId: org,
        sheetUrl: 'url',
        sheetName: id,
        rows: const [],
        columns: const [],
        fetchedAt: fetchedAt,
        rowCount: 0,
        version: 1,
      );

  test('sourcesListProvider returns only the requested organization',
      () async {
    final storage = _MemoryCacheStorage([
      cache('a', 'org-a', now),
      cache('b', 'org-a', now.add(const Duration(minutes: 1))),
      cache('c', 'org-b', now),
    ]);

    final container = ProviderContainer(
      overrides: [
        sheetCacheStorageReadyProvider.overrideWith((ref) => true),
        sheetCacheManagerProvider.overrideWith(
          (ref) => SheetCacheManager(storage),
        ),
      ],
    );
    addTearDown(container.dispose);

    final orgA = await container.read(sourcesListProvider('org-a').future);
    expect(orgA.map((s) => s.sourceId), ['b', 'a']);

    final orgB = await container.read(sourcesListProvider('org-b').future);
    expect(orgB.map((s) => s.sourceId), ['c']);

    final orgC = await container.read(sourcesListProvider('org-c').future);
    expect(orgC, isEmpty);
  });

  test('sourcesListProvider returns empty for an empty organization id',
      () async {
    final storage = _MemoryCacheStorage([cache('a', 'org-a', now)]);

    final container = ProviderContainer(
      overrides: [
        sheetCacheStorageReadyProvider.overrideWith((ref) => true),
        sheetCacheManagerProvider.overrideWith(
          (ref) => SheetCacheManager(storage),
        ),
      ],
    );
    addTearDown(container.dispose);

    final list = await container.read(sourcesListProvider('').future);
    expect(list, isEmpty);
  });
}

class _MemoryCacheStorage implements SheetCacheStorage {
  _MemoryCacheStorage(List<SheetCacheModel> caches)
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