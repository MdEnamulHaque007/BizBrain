import 'package:bizbrain/features/data_sources/data/google_sheets/google_sheets_loader.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_manager.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';
import 'package:bizbrain/features/data_sources/domain/entities/data_source.dart';
import 'package:bizbrain/features/data_sources/domain/entities/google_sheets_data_source.dart';
import 'package:bizbrain/features/data_sources/domain/repositories/data_source_repository.dart';

/// Repository providing a cache-first interface to Google Sheets data stored
/// locally. It also implements the broader DataSourceRepository contract used
/// by the feature for listing data sources per organization.
class CachedDataSourceRepository implements DataSourceRepository {
  CachedDataSourceRepository({
    required GoogleSheetsLoader loader,
    required SheetCacheManager cache,
  }) : _loader = loader,
       _cache = cache;

  final GoogleSheetsLoader _loader;
  final SheetCacheManager _cache;

  // DataSourceRepository requirement: stream of DataSource per organization.
  @override
  Stream<List<DataSource>> watchForOrganization(String organizationId) async* {
    yield await _buildList(organizationId);
    yield* Stream<void>.periodic(
      const Duration(seconds: 3),
    ).asyncMap((_) => _buildList(organizationId));
  }

  Future<List<DataSource>> _buildList(String organizationId) async {
    final cached = await _cache.list(organizationId: organizationId);
    return cached
        .map(
          (c) => DataSource(
            id: c.sourceId,
            organizationId: c.organizationId,
            name: c.sheetName ?? c.sheetUrl,
            kind: DataSourceKind.spreadsheet,
            status: DataSourceConnectionStatus.connected,
            lastSyncedAt: c.fetchedAt,
          ),
        )
        .toList(growable: false);
  }

  /// Cache-first getter for a Google Sheets source. [sourceId] is the unique
  /// id chosen by the caller (e.g. spreadsheet id + range + sheet name).
  Future<SheetCacheModel?> getDataSource(String sourceId) =>
      _cache.getCached(sourceId);

  /// Returns the cached data for this organization, or fetches and stores it
  /// when no matching organization-scoped cache exists.
  Future<SheetCacheModel> loadDataSource({
    required GoogleSheetsDataSource source,
    required String sourceId,
    required String organizationId,
  }) async {
    final cached = await _cache.getCached(sourceId);
    if (cached != null && cached.organizationId == organizationId) {
      return cached;
    }
    return refreshDataSource(
      source: source,
      sourceId: sourceId,
      organizationId: organizationId,
    );
  }

  /// Force-fetch from Google Sheets, overwrite cache and return the saved model.
  Future<SheetCacheModel> refreshDataSource({
    required GoogleSheetsDataSource source,
    required String sourceId,
    required String organizationId,
  }) async {
    final table = await _loader.load(source);
    final model = SheetCacheModel(
      sourceId: sourceId,
      organizationId: organizationId,
      sheetUrl: table.metadata.sourceUrl,
      sheetName: table.metadata.sheetName,
      rows: table
          .toRecords()
          .map((r) => Map<String, String>.from(r))
          .toList(growable: false),
      columns: List<String>.from(table.headers),
      fetchedAt: table.metadata.loadedAt,
      rowCount: table.rowCount,
      version: 1,
    );
    await _cache.saveCache(model);
    return model;
  }

  Future<void> deleteDataSource(String sourceId) => _cache.invalidate(sourceId);

  Stream<SheetCacheModel?> watchDataSource(String sourceId) =>
      _cache.watch(sourceId);

  Future<List<SheetCacheModel>> listDataSources({String? organizationId}) =>
      _cache.list(organizationId: organizationId);
}
