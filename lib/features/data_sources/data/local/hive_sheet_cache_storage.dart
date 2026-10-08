import 'dart:async';

import 'package:bizbrain/core/logging/app_logger.dart';
import 'package:hive/hive.dart';

import 'sheet_cache_model.dart';
import 'sheet_cache_storage.dart';

class HiveSheetCacheStorage implements SheetCacheStorage {
  HiveSheetCacheStorage();

  static const String _boxName = 'sheet_cache_v1';
  Future<Box<SheetCacheModel>> get _openBox async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<SheetCacheModel>(_boxName);
    }
    return Hive.openBox<SheetCacheModel>(_boxName);
  }

  String _key(String sourceId) => sourceId;

  @override
  Future<void> save(SheetCacheModel cache) async {
    try {
      final box = await _openBox;
      await box.put(_key(cache.sourceId), cache);
      AppLogger.debug('Saved cache for ${cache.sourceId}');
    } catch (e, st) {
      AppLogger.error('Failed to save cache', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<SheetCacheModel?> get(String sourceId) async {
    try {
      final box = await _openBox;
      return box.get(_key(sourceId));
    } catch (e, st) {
      AppLogger.error('Failed to read cache', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<List<SheetCacheModel>> getAll({String? organizationId}) async {
    final box = await _openBox;
    final results = <SheetCacheModel>[];
    for (final entry in box.toMap().entries) {
      try {
        final model = entry.value;
        if (organizationId == null || model.organizationId == organizationId) {
          results.add(model);
        }
      } catch (e, st) {
        AppLogger.warning(
          'Failed to parse cache entry ${entry.key}',
          error: e,
          stackTrace: st,
        );
      }
    }
    return results;
  }

  @override
  Future<void> delete(String sourceId) async {
    final box = await _openBox;
    await box.delete(_key(sourceId));
    AppLogger.debug('Deleted cache for $sourceId');
  }

  @override
  Future<void> clearAll({String? organizationId}) async {
    final box = await _openBox;
    if (organizationId == null) {
      await box.clear();
      AppLogger.debug('Cleared all sheet caches');
      return;
    }
    final keysToRemove = <dynamic>[];
    for (final entry in box.toMap().entries) {
      try {
        final model = entry.value;
        if (model.organizationId == organizationId) keysToRemove.add(entry.key);
      } catch (e, st) {
        AppLogger.warning(
          'Failed to inspect cache entry ${entry.key}',
          error: e,
          stackTrace: st,
        );
      }
    }
    for (final k in keysToRemove) {
      await box.delete(k);
    }
    AppLogger.debug('Cleared caches for org $organizationId');
  }

  @override
  Future<bool> exists(String sourceId) async {
    final box = await _openBox;
    return box.containsKey(_key(sourceId));
  }

  @override
  Future<DateTime?> getLastFetchTime(String sourceId) async {
    final model = await get(sourceId);
    return model?.fetchedAt;
  }

  @override
  Stream<SheetCacheModel?> watch(String sourceId) {
    return Stream<SheetCacheModel?>.multi((controller) {
      _watch(sourceId, controller);
    });
  }

  Future<void> _watch(
    String sourceId,
    MultiStreamController<SheetCacheModel?> controller,
  ) async {
    try {
      final box = await _openBox;
      final subscription = box
          .watch(key: _key(sourceId))
          .listen(
            (_) => controller.add(box.get(_key(sourceId))),
            onError: controller.addError,
          );
      controller.onCancel = subscription.cancel;
      controller.add(box.get(_key(sourceId)));
    } catch (error, stackTrace) {
      controller.addError(error, stackTrace);
    }
  }
}
