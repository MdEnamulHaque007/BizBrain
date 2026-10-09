import 'dart:convert';

import 'package:bizbrain/core/logging/app_logger.dart';
import 'sheet_cache_model.dart';
import 'sheet_cache_storage.dart';

class SheetCacheManager {
  SheetCacheManager(
    this._storage, {
    this.defaultStaleThreshold = const Duration(days: 7),
    this.maxCacheSizeBytes = 50 * 1024 * 1024,
  });

  final SheetCacheStorage _storage;
  final Duration defaultStaleThreshold;
  final int maxCacheSizeBytes;

  Future<SheetCacheModel?> getCached(String sourceId) => _storage.get(sourceId);

  Future<void> saveCache(SheetCacheModel cache) async {
    try {
      await _storage.save(cache);
      AppLogger.info('Sheet cache saved ${cache.sourceId}');
      await _enforceSizeLimit(cache.organizationId);
    } catch (e, st) {
      AppLogger.error('Failed to save sheet cache', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> invalidate(String sourceId) async {
    try {
      await _storage.delete(sourceId);
      AppLogger.info('Invalidated cache for $sourceId');
    } catch (e, st) {
      AppLogger.error('Failed to invalidate cache', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> invalidateAll({String? organizationId}) async {
    try {
      await _storage.clearAll(organizationId: organizationId);
      AppLogger.info('Invalidated caches for org ${organizationId ?? 'ALL'}');
    } catch (e, st) {
      AppLogger.error('Failed to invalidate caches', error: e, stackTrace: st);
      rethrow;
    }
  }

  bool isStale(SheetCacheModel cache, {Duration? threshold}) {
    final t = threshold ?? defaultStaleThreshold;
    return DateTime.now().difference(cache.fetchedAt) > t;
  }

  Future<Duration?> getCacheAge(String sourceId) async {
    final fetched = await _storage.getLastFetchTime(sourceId);
    if (fetched == null) return null;
    return DateTime.now().difference(fetched);
  }

  Future<List<SheetCacheModel>> list({String? organizationId}) =>
      _storage.getAll(organizationId: organizationId);

  Future<List<SheetCacheModel>> listSources({String? organizationId}) =>
      list(organizationId: organizationId);

  Future<void> deleteSource(String sourceId) => invalidate(sourceId);

  Future<SheetCacheModel> refreshSource({
    required String sourceId,
    required Future<SheetCacheModel> Function() fetch,
  }) async {
    final fresh = await fetch();
    if (fresh.sourceId != sourceId) {
      throw ArgumentError.value(
        fresh.sourceId,
        'sourceId',
        'Refreshed source ID does not match the requested source.',
      );
    }
    await saveCache(fresh);
    return fresh;
  }

  Stream<SheetCacheModel?> watch(String sourceId) => _storage.watch(sourceId);

  // Lightweight eviction: if total JSON size for org exceeds limit, drop oldest.
  Future<void> _enforceSizeLimit(String organizationId) async {
    final all = await _storage.getAll(organizationId: organizationId);
    var total = 0;
    final items = <MapEntry<SheetCacheModel, int>>[];
    for (final m in all) {
      final size = utf8.encode(jsonEncode(m.toJson())).length;
      total += size;
      items.add(MapEntry(m, size));
    }
    if (total <= maxCacheSizeBytes) return;
    // Evict oldest until under limit
    items.sort((a, b) => a.key.fetchedAt.compareTo(b.key.fetchedAt));
    var i = 0;
    while (total > maxCacheSizeBytes && i < items.length) {
      final toRemove = items[i];
      await _storage.delete(toRemove.key.sourceId);
      total -= toRemove.value;
      AppLogger.info(
        'Evicted cache ${toRemove.key.sourceId} to enforce size limit',
      );
      i++;
    }
  }
}
