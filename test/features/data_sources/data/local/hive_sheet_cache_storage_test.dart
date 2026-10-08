import 'dart:async';
import 'dart:io';

import 'package:bizbrain/features/data_sources/data/local/hive_sheet_cache_storage.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  late HiveSheetCacheStorage storage;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('bizbrain_sheet_cache_');
    Hive.init(directory.path);
    Hive.registerAdapter(SheetCacheModelAdapter());
  });

  setUp(() async {
    storage = HiveSheetCacheStorage();
    await (await Hive.openBox<SheetCacheModel>('sheet_cache_v1')).clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('saves and retrieves typed cache entries', () async {
    final cache = createCache('one', 'org-a');

    await storage.save(cache);

    expect(await storage.get('one'), cache);
    expect(await storage.exists('one'), isTrue);
    expect(await storage.getLastFetchTime('one'), cache.fetchedAt);
  });

  test('filters and clears entries by organization', () async {
    await storage.save(createCache('one', 'org-a'));
    await storage.save(createCache('two', 'org-b'));

    expect(
      (await storage.getAll(
        organizationId: 'org-a',
      )).map((entry) => entry.sourceId),
      ['one'],
    );

    await storage.clearAll(organizationId: 'org-a');
    expect(await storage.get('one'), isNull);
    expect(await storage.get('two'), isNotNull);
  });

  test('watch emits initial and updated cache values', () async {
    final iterator = StreamIterator(storage.watch('watched'));
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current, isNull);

    final cache = createCache('watched', 'org-a');
    await storage.save(cache);
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current, cache);
    await iterator.cancel();
  });

  test('deletes the cache entry', () async {
    await storage.save(createCache('one', 'org-a'));

    await storage.delete('one');

    expect(await storage.get('one'), isNull);
    expect(await storage.exists('one'), isFalse);
  });
}

SheetCacheModel createCache(String id, String organizationId) =>
    SheetCacheModel(
      sourceId: id,
      organizationId: organizationId,
      sheetUrl: 'https://example.com/$id',
      sheetName: 'Inventory',
      rows: const [
        {'Name': 'Boot'},
      ],
      columns: const ['Name'],
      fetchedAt: DateTime.utc(2026, 10, 8),
      rowCount: 1,
      version: 1,
    );
