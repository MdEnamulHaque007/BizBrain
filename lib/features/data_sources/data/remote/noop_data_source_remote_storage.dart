import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';

import 'data_source_remote_storage.dart';

/// [DataSourceRemoteStorage] that does nothing.
///
/// Used in guest mode and for builds where Firebase is not configured, so
/// data sources keep working exactly as before while no cloud is available.
class NoopDataSourceRemoteStorage implements DataSourceRemoteStorage {
  const NoopDataSourceRemoteStorage();

  @override
  Future<void> push(SheetCacheModel model, {required String uid}) async {}

  @override
  Future<void> delete(String sourceId, {required String uid}) async {}

  @override
  Future<List<SheetCacheModel>> pull({
    required String uid,
    required String organizationId,
  }) async => const <SheetCacheModel>[];
}