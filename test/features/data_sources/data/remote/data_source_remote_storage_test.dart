import 'package:bizbrain/features/data_sources/data/local/sheet_cache_manager.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_storage.dart';
import 'package:bizbrain/features/data_sources/data/remote/data_source_remote_storage.dart';
import 'package:bizbrain/features/data_sources/data/remote/noop_data_source_remote_storage.dart';
import 'package:bizbrain/features/data_sources/presentation/providers/data_source_sync_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('capRowsForRemote', () {
    test('keeps unchanged when rows fit within the budget', () {
      final model = _model(rows: 3, rowValue: 'x');

      final capped = capRowsForRemote(model);

      expect(capped.rows, model.rows);
      expect(capped.rowCount, 3);
    });

    test('caps the number of rows and preserves the full row count', () {
      final model = _model(rows: 1000, rowValue: 'x');

      final capped = capRowsForRemote(model, maxRows: 500, maxBytes: 10 * 1024 * 1024);

      expect(capped.rows.length, 500);
      expect(capped.rowCount, 1000);
      expect(capped.sourceId, model.sourceId);
      expect(capped.columns, model.columns);
    });

    test('caps by byte budget', () {
      final model = _model(rows: 200, rowValue: 'a' * 1000);

      final capped = capRowsForRemote(model, maxRows: 500, maxBytes: 10000);

      expect(capped.rows.length, greaterThan(0));
      expect(capped.rows.length, lessThan(200));
      expect(capped.rowCount, 200);
    });

    test('keeps empty rows unchanged', () {
      final model = _model(rows: 0);

      final capped = capRowsForRemote(model);

      expect(capped, model);
    });
  });

  group('DataSourceSyncService', () {
    test('push forwards the model and uid to the remote', () async {
      final remote = _FakeRemote();
      final service = DataSourceSyncService(
        remote: remote,
        cache: SheetCacheManager(_MemoryStorage()),
      );

      await service.push(_model(rows: 2), uid: 'u-1');

      expect(remote.pushed.length, 1);
      expect(remote.pushed.first.uid, 'u-1');
      expect(remote.pushed.first.model.sourceId, _model(rows: 2).sourceId);
    });

    test('push swallows remote failures', () async {
      final remote = _FakeRemote()..pushError = Exception('offline');
      final service = DataSourceSyncService(
        remote: remote,
        cache: SheetCacheManager(_MemoryStorage()),
      );

      await expectLater(
        service.push(_model(rows: 1), uid: 'u-1'),
        completes,
      );
    });

    test('delete forwards and swallows remote failures', () async {
      final remote = _FakeRemote()..deleteError = Exception('offline');
      final service = DataSourceSyncService(
        remote: remote,
        cache: SheetCacheManager(_MemoryStorage()),
      );

      await expectLater(service.delete('s-1', uid: 'u-1'), completes);
    });

    test('pull restores remote sources stamped to the current organization',
        () async {
      final storage = _MemoryStorage();
      final remote = _FakeRemote()
        ..pullResult = [
          _model(sourceId: 'remote-1', organizationId: 'org-from-cloud'),
        ];
      final service = DataSourceSyncService(
        remote: remote,
        cache: SheetCacheManager(storage),
      );

      final pulled = await service.pull(uid: 'u-1', organizationId: 'org-1');

      expect(pulled.length, 1);
      final saved = await storage.get('remote-1');
      expect(saved, isNotNull);
      expect(saved!.organizationId, 'org-1');
    });

    test('pull keeps the local copy when it is at least as fresh', () async {
      final fetchedAt = DateTime.utc(2026, 6, 1);
      final storage = _MemoryStorage([
        _model(
          sourceId: 's-1',
          organizationId: 'org-1',
          fetchedAt: fetchedAt,
          rowValue: 'local',
        ),
      ]);
      final remote = _FakeRemote()
        ..pullResult = [
          _model(
            sourceId: 's-1',
            organizationId: 'org-1',
            fetchedAt: fetchedAt,
            rowValue: 'remote',
          ),
        ];
      final service = DataSourceSyncService(
        remote: remote,
        cache: SheetCacheManager(storage),
      );

      await service.pull(uid: 'u-1', organizationId: 'org-1');

      expect((await storage.get('s-1'))!.rows.first['Name'], 'local');
    });

    test('pull overwrites with the remote copy when it is newer', () async {
      final storage = _MemoryStorage([
        _model(
          sourceId: 's-1',
          organizationId: 'org-1',
          fetchedAt: DateTime.utc(2026, 6, 1),
          rowValue: 'local',
        ),
      ]);
      final remote = _FakeRemote()
        ..pullResult = [
          _model(
            sourceId: 's-1',
            organizationId: 'org-1',
            fetchedAt: DateTime.utc(2026, 6, 2),
            rowValue: 'remote',
          ),
        ];
      final service = DataSourceSyncService(
        remote: remote,
        cache: SheetCacheManager(storage),
      );

      await service.pull(uid: 'u-1', organizationId: 'org-1');

      expect((await storage.get('s-1'))!.rows.first['Name'], 'remote');
    });

    test('pull moves a source into the current org when orgs differ',
        () async {
      final storage = _MemoryStorage([
        _model(
          sourceId: 's-1',
          organizationId: 'old-org',
          fetchedAt: DateTime.utc(2026, 6, 2),
          rowValue: 'local',
        ),
      ]);
      final remote = _FakeRemote()
        ..pullResult = [
          _model(
            sourceId: 's-1',
            organizationId: 'cloud-org',
            fetchedAt: DateTime.utc(2026, 6, 2),
          ),
        ];
      final service = DataSourceSyncService(
        remote: remote,
        cache: SheetCacheManager(storage),
      );

      await service.pull(uid: 'u-1', organizationId: 'org-1');

      expect((await storage.get('s-1'))!.organizationId, 'org-1');
    });

    test('pull returns an empty list and keeps local data when the remote fails',
        () async {
      final storage = _MemoryStorage([
        _model(sourceId: 's-1', organizationId: 'org-1', rowValue: 'local'),
      ]);
      final remote = _FakeRemote()..pullError = Exception('offline');
      final service = DataSourceSyncService(
        remote: remote,
        cache: SheetCacheManager(storage),
      );

      final pulled = await service.pull(uid: 'u-1', organizationId: 'org-1');

      expect(pulled, isEmpty);
      expect((await storage.get('s-1'))!.rows.first['Name'], 'local');
    });
  });

  group('DataSourceSyncBootstrap', () {
    test('runs once per (uid, organization) pair', () async {
      final remote = _FakeRemote();
      final service = DataSourceSyncService(
        remote: remote,
        cache: SheetCacheManager(_MemoryStorage()),
      );
      final controller = DataSourceSyncBootstrap();
      final invalidated = <String>[];

      await controller.run(
        sync: service,
        uid: 'u-1',
        organizationId: 'org-1',
        onPulled: invalidated.add,
      );
      await controller.run(
        sync: service,
        uid: 'u-1',
        organizationId: 'org-1',
        onPulled: invalidated.add,
      );
      await controller.run(
        sync: service,
        uid: 'u-1',
        organizationId: 'org-2',
        onPulled: invalidated.add,
      );

      expect(remote.pullCount, 2);
      expect(invalidated, ['org-1', 'org-2']);
    });
  });

  group('NoopDataSourceRemoteStorage', () {
    test('all operations are no-ops', () async {
      const remote = NoopDataSourceRemoteStorage();

      await remote.push(_model(rows: 1), uid: 'u-1');
      await remote.delete('s-1', uid: 'u-1');
      final pulled = await remote.pull(uid: 'u-1', organizationId: 'org-1');

      expect(pulled, isEmpty);
    });
  });
}

SheetCacheModel _model({
  String sourceId = 'abcdefghijk|Inventory|A1:B5|1',
  String organizationId = 'org-1',
  DateTime? fetchedAt,
  int rows = 1,
  String rowValue = 'Boot',
  bool useCustom = false,
}) => SheetCacheModel(
  sourceId: sourceId,
  organizationId: organizationId,
  sheetUrl: 'https://docs.google.com/spreadsheets/d/abcdefghijk/gviz/tq',
  sheetName: 'Inventory',
  rows: List<Map<String, String>>.generate(
    rows,
    (i) => {'Name': useCustom ? '$rowValue $i' : rowValue, 'Qty': '4'},
    growable: true,
  ),
  columns: const ['Name', 'Qty'],
  fetchedAt: fetchedAt ?? DateTime.utc(2026, 6, 1),
  rowCount: rows,
  version: 1,
);

class _FakeRemote implements DataSourceRemoteStorage {
  List<({String uid, SheetCacheModel model})> pushed = [];
  int pullCount = 0;
  List<SheetCacheModel> pullResult = const [];
  Object? pushError;
  Object? deleteError;
  Object? pullError;

  @override
  Future<void> push(SheetCacheModel model, {required String uid}) async {
    final error = pushError;
    if (error != null) throw error;
    pushed.add((uid: uid, model: model));
  }

  @override
  Future<void> delete(String sourceId, {required String uid}) async {
    final error = deleteError;
    if (error != null) throw error;
  }

  @override
  Future<List<SheetCacheModel>> pull({
    required String uid,
    required String organizationId,
  }) async {
    pullCount++;
    final error = pullError;
    if (error != null) throw error;
    return pullResult
        .map((model) => model.copyWith(organizationId: organizationId))
        .toList();
  }
}

class _MemoryStorage implements SheetCacheStorage {
  _MemoryStorage([List<SheetCacheModel> caches = const []])
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

  void clear() => _values.clear();

  @override
  Future<bool> exists(String sourceId) async => _values.containsKey(sourceId);

  @override
  Future<DateTime?> getLastFetchTime(String sourceId) async {
    final cache = _values[sourceId];
    if (cache == null) return null;
    return cache.fetchedAt;
  }

  @override
  Stream<SheetCacheModel?> watch(String sourceId) async* {
    yield _values[sourceId];
  }
}