import 'dart:io';

import 'package:bizbrain/features/authentication/presentation/providers/auth_providers.dart';
import 'package:bizbrain/features/authentication/presentation/providers/auth_state.dart';
import 'package:bizbrain/features/data_sources/data/local/hive_sheet_cache_storage.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../../../../support/app_test_helpers.dart';

void main() {
  late Directory directory;
  late HiveSheetCacheStorage storage;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('bizbrain_auth_');
    Hive.init(directory.path);
    Hive.registerAdapter(SheetCacheModelAdapter());
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  setUp(() async {
    storage = HiveSheetCacheStorage();
    await (await Hive.openBox<SheetCacheModel>('sheet_cache_v1')).clear();
  });

  ProviderContainer buildContainer(FakeAuthRepository auth) {
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('signOut clears every cached sheet across organizations', () async {
    await storage.save(cachedSheet('a', 'org-a'));
    await storage.save(cachedSheet('b', 'org-b'));

    final container = buildContainer(
      FakeAuthRepository(isConfigured: true, initialUser: testUser),
    );

    await container.read(authControllerProvider.notifier).signOut();

    expect(await storage.getAll(), isEmpty);
    expect(container.read(authControllerProvider).status, AuthStatus.unauthenticated);
  });

  test('a session that ends without the button still clears the cache',
      () async {
    await storage.save(cachedSheet('a', 'org-a'));

    final auth = FakeAuthRepository(isConfigured: true, initialUser: testUser);
    final container = buildContainer(auth);

    // Wait for the initial session so the stream listener is live before the
    // session ends.
    for (var i = 0;
        i < 20 &&
            container.read(authControllerProvider).status !=
                AuthStatus.authenticated;
        i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.authenticated,
    );

    auth.emit(null);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(await storage.getAll(), isEmpty);
    expect(container.read(authControllerProvider).status, AuthStatus.unauthenticated);
  });

  test('entering guest mode clears a previous tenant cache', () async {
    await storage.save(cachedSheet('a', 'org-a'));

    final container = buildContainer(FakeAuthRepository(isConfigured: true));

    container.read(authControllerProvider.notifier).continueAsGuest();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(await storage.getAll(), isEmpty);
    expect(container.read(authControllerProvider).status, AuthStatus.guest);
  });
}

SheetCacheModel cachedSheet(String id, String organizationId) => SheetCacheModel(
  sourceId: id,
  organizationId: organizationId,
  sheetUrl: 'https://example.com/$id',
  sheetName: 'Inventory',
  rows: const [
    {'Name': 'Boot'},
  ],
  columns: const ['Name'],
  fetchedAt: DateTime.utc(2026, 1, 8),
  rowCount: 1,
  version: 1,
);
