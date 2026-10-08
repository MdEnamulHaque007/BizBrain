import 'package:bizbrain/features/data_sources/data/google_sheets/google_sheets_loader.dart';
import 'package:bizbrain/features/data_sources/data/local/hive_sheet_cache_storage.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_manager.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_storage.dart';
import 'package:bizbrain/features/data_sources/data/repositories/cached_data_source_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// Shared read-only Google Sheets loader.
///
/// One HTTP client is reused for the session; it is closed when the provider
/// is disposed. Tests override this provider with a loader backed by a mock
/// HTTP client.
final Provider<GoogleSheetsLoader> googleSheetsLoaderProvider =
    Provider<GoogleSheetsLoader>((Ref ref) {
      final loader = GoogleSheetsLoader();
      ref.onDispose(loader.close);
      return loader;
    });

/// Storage implementation using Hive.
final Provider<SheetCacheStorage> sheetCacheStorageProvider =
    Provider<SheetCacheStorage>((ref) {
      return HiveSheetCacheStorage();
    });

/// Indicates that app bootstrap initialized Hive and opened the cache box.
final Provider<bool> sheetCacheStorageReadyProvider = Provider<bool>(
  (ref) => Hive.isBoxOpen('sheet_cache_v1'),
);

/// Manager that wraps storage and provides higher-level helpers.
final Provider<SheetCacheManager> sheetCacheManagerProvider =
    Provider<SheetCacheManager>((ref) {
      return SheetCacheManager(ref.read(sheetCacheStorageProvider));
    });

/// All locally cached Google Sheets sources, loaded when the feature starts.
final FutureProvider<List<SheetCacheModel>> cachedSourcesProvider =
    FutureProvider<List<SheetCacheModel>>((ref) async {
      final sources = await ref.read(sheetCacheManagerProvider).list();
      sources.sort((a, b) => b.fetchedAt.compareTo(a.fetchedAt));
      return sources;
    });

/// Cached repository for data sources.
final Provider<CachedDataSourceRepository> cachedDataSourceRepositoryProvider =
    Provider<CachedDataSourceRepository>((ref) {
      return CachedDataSourceRepository(
        loader: ref.read(googleSheetsLoaderProvider),
        cache: ref.read(sheetCacheManagerProvider),
      );
    });
