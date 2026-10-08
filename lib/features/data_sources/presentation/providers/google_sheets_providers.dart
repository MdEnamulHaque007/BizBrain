import 'package:bizbrain/features/data_sources/data/google_sheets/google_sheets_loader.dart';
import 'package:bizbrain/features/data_sources/data/local/hive_sheet_cache_storage.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_manager.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_storage.dart';
import 'package:bizbrain/features/data_sources/data/repositories/cached_data_source_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Manager that wraps storage and provides higher-level helpers.
final Provider<SheetCacheManager> sheetCacheManagerProvider =
    Provider<SheetCacheManager>((ref) {
      return SheetCacheManager(ref.read(sheetCacheStorageProvider));
    });

/// Cached repository for data sources.
final Provider<CachedDataSourceRepository> cachedDataSourceRepositoryProvider =
    Provider<CachedDataSourceRepository>((ref) {
      return CachedDataSourceRepository(
        loader: ref.read(googleSheetsLoaderProvider),
        cache: ref.read(sheetCacheManagerProvider),
      );
    });
