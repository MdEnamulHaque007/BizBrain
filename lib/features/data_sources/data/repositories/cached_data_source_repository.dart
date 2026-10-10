import 'package:bizbrain/core/logging/app_logger.dart';
import 'package:bizbrain/features/data_sources/data/google_sheets/google_sheets_loader.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_manager.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';
import 'package:bizbrain/features/data_sources/domain/entities/google_sheets_data_source.dart';

/// Repository providing a cache-first interface to Google Sheets data stored
/// locally.
class CachedDataSourceRepository {
  CachedDataSourceRepository({
    required GoogleSheetsLoader loader,
    required SheetCacheManager cache,
  }) : _loader = loader,
       _cache = cache;

  final GoogleSheetsLoader _loader;
  final SheetCacheManager _cache;

  /// Returns the cached data for this organization, or fetches and stores it
  /// when no matching organization-scoped cache exists.
  Future<SheetCacheModel> loadDataSource({
    required GoogleSheetsDataSource source,
    required String sourceId,
    required String organizationId,
    String? sourceLabel,
    String? sourceInput,
  }) async {
    final cached = await _cache.getCached(sourceId);
    if (cached != null && cached.organizationId == organizationId) {
      AppLogger.info('Cache HIT for sourceId: $sourceId');
      final updated = cached.copyWith(
        sourceLabel: sourceLabel,
        // Never clear an existing label on a cache hit: a caller without an
        // explicit label must not wipe what the user already saved.
        clearSourceLabel: false,
        sourceInput: sourceInput,
        dataRange: source.dataRange,
        headerRow: source.headerRow,
      );
      if (updated != cached) {
        await _cache.saveCache(updated);
      }
      return updated;
    }

    final legacySourceId =
        '${source.spreadsheetId}|${source.sheetName ?? ''}|${source.dataRange ?? ''}|h${source.headerRow}';
    if (legacySourceId != sourceId) {
      final legacyCache = await _cache.getCached(legacySourceId);
      if (legacyCache != null && legacyCache.organizationId == organizationId) {
        AppLogger.info('Cache HIT for sourceId: $sourceId');
        final migratedCache = legacyCache.copyWith(
          sourceId: sourceId,
          sourceLabel: sourceLabel,
          clearSourceLabel: false,
          sourceInput: sourceInput,
          dataRange: source.dataRange,
          headerRow: source.headerRow,
        );
        await _cache.saveCache(migratedCache);
        await _cache.invalidate(legacySourceId);
        return migratedCache;
      }
    }

    AppLogger.info('Cache MISS for sourceId: $sourceId');
    return refreshDataSource(
      source: source,
      sourceId: sourceId,
      organizationId: organizationId,
      sourceLabel: sourceLabel,
      sourceInput: sourceInput,
    );
  }

  /// Force-fetch from Google Sheets, overwrite cache and return the saved model.
  Future<SheetCacheModel> refreshDataSource({
    required GoogleSheetsDataSource source,
    required String sourceId,
    required String organizationId,
    String? sourceLabel,
    String? sourceInput,
  }) async {
    final table = await _loader.load(source);
    return _cache.refreshSource(
      sourceId: sourceId,
      fetch: () async => SheetCacheModel(
        sourceId: sourceId,
        organizationId: organizationId,
        sheetUrl: table.metadata.sourceUrl,
        sheetName: table.metadata.sheetName,
        rows: table
            .toRecords()
            .map((record) => Map<String, String>.from(record))
            .toList(growable: false),
        columns: List<String>.from(table.headers),
        fetchedAt: table.metadata.loadedAt,
        rowCount: table.rowCount,
        version: 1,
        sourceLabel: sourceLabel,
        sourceInput: sourceInput,
        dataRange: source.dataRange,
        headerRow: source.headerRow,
      ),
    );
  }

Future<void> deleteDataSource(String sourceId) => _cache.invalidate(sourceId);
}
