import 'package:bizbrain/features/authentication/presentation/providers/auth_providers.dart';
import 'package:bizbrain/features/data_sources/data/google_sheets/google_sheets_loader.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_manager.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_storage.dart';
import 'package:bizbrain/features/data_sources/data/remote/data_source_remote_storage.dart';
import 'package:bizbrain/features/data_sources/data/repositories/cached_data_source_repository.dart';
import 'package:bizbrain/features/data_sources/presentation/providers/data_source_sync_providers.dart';
import 'package:bizbrain/features/data_sources/presentation/providers/google_sheets_providers.dart';
import 'package:bizbrain/features/data_sources/presentation/widgets/google_sheets_preview_panel.dart';
import 'package:bizbrain/features/organizations/domain/entities/organization.dart';
import 'package:bizbrain/features/organizations/presentation/providers/organization_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../../support/app_test_helpers.dart';

final Organization _testOrg = Organization(
  id: 'org-1',
  name: 'Acme',
  ownerId: 'u-test',
  memberIds: ['u-test'],
  status: OrganizationStatus.active,
  createdAt: DateTime.utc(2026, 1, 1),
);

void main() {
  testWidgets('Connect pushes the loaded source to the cloud', (tester) async {
    final storage = _MemoryStorage();
    final manager = SheetCacheManager(storage);
    final remote = _RecordingRemote();
    final repository = CachedDataSourceRepository(
      loader: GoogleSheetsLoader(
        client: MockClient((_) async => http.Response('Name,Qty\nBoot,4\n', 200)),
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
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(isConfigured: true, initialUser: testUser),
          ),
          dataSourceRemoteStorageProvider.overrideWithValue(remote),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: GoogleSheetsPreviewPanel()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The sig-in screen normally establishes the session before the data
    // sources panel is reachable; reproduce that by building/initializing the
    // auth controller here so `_signedInUid` resolves.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GoogleSheetsPreviewPanel)),
    );
    container.read(authControllerProvider);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'abcdefghijk');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(find.text('Boot'), findsOneWidget);
    expect(remote.pushed.length, 1);
    expect(remote.pushed.first.uid, 'u-test');
    expect(remote.pushed.first.sourceId, startsWith('abcdefghijk|'));
  });

  testWidgets('Sync cloud restores saved sources into the local cache',
      (tester) async {
    final storage = _MemoryStorage();
    final manager = SheetCacheManager(storage);
    final remote = _RecordingRemote()
      ..pullResult = [
        SheetCacheModel(
          sourceId: 'abcdefghijk|Inventory|A1:B5|1',
          organizationId: 'org-from-cloud',
          sheetUrl: 'https://docs.google.com/spreadsheets/d/abcdefghijk/gviz/tq',
          sheetName: 'Inventory',
          rows: const [
            {'Name': 'Boot', 'Qty': '4'},
          ],
          columns: const ['Name', 'Qty'],
          fetchedAt: DateTime.utc(2026, 6, 1),
          rowCount: 1,
          version: 1,
          sourceInput: 'abcdefghijk',
        ),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sheetCacheStorageReadyProvider.overrideWith((ref) => true),
          activeOrganizationProvider.overrideWithValue(_testOrg),
          sourcesListProvider('org-1').overrideWith((ref) async => []),
          sheetCacheManagerProvider.overrideWith((ref) => manager),
          cachedDataSourceRepositoryProvider.overrideWith(
            (ref) => CachedDataSourceRepository(
              loader: GoogleSheetsLoader(
                client: MockClient(
                  (_) async => http.Response('Name,Qty\nBoot,4\n', 200),
                ),
              ),
              cache: manager,
            ),
          ),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(isConfigured: true, initialUser: testUser),
          ),
          dataSourceRemoteStorageProvider.overrideWithValue(remote),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: GoogleSheetsPreviewPanel()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GoogleSheetsPreviewPanel)),
    );
    container.read(authControllerProvider);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Sync cloud'));
    await tester.tap(find.text('Sync cloud'));
    await tester.pumpAndSettle();

    final saved = await storage.get('abcdefghijk|Inventory|A1:B5|1');
    expect(saved, isNotNull);
    expect(saved!.organizationId, 'org-1');
    expect(saved.rows.first['Name'], 'Boot');
    expect(find.textContaining('Restored 1 source'), findsOneWidget);
  });
}

class _RecordingRemote implements DataSourceRemoteStorage {
  final List<({String uid, String sourceId})> pushed = [];
  List<SheetCacheModel> pullResult = const [];

  @override
  Future<void> push(SheetCacheModel model, {required String uid}) async {
    pushed.add((uid: uid, sourceId: model.sourceId));
  }

  @override
  Future<void> delete(String sourceId, {required String uid}) async {}

  @override
  Future<List<SheetCacheModel>> pull({
    required String uid,
    required String organizationId,
  }) async {
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