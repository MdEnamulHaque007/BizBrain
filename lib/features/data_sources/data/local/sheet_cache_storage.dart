import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';

abstract class SheetCacheStorage {
  Future<void> save(SheetCacheModel cache);
  Future<SheetCacheModel?> get(String sourceId);
  Future<List<SheetCacheModel>> getAll({String? organizationId});
  Future<void> delete(String sourceId);
  Future<void> clearAll({String? organizationId});
  Future<bool> exists(String sourceId);
  Future<DateTime?> getLastFetchTime(String sourceId);
  Stream<SheetCacheModel?> watch(String sourceId);
}
