import 'dart:async';

import 'package:bizbrain/core/config/app_providers.dart';
import 'package:bizbrain/core/logging/app_logger.dart';
import 'package:bizbrain/features/authentication/presentation/providers/auth_providers.dart';
import 'package:bizbrain/features/authentication/presentation/providers/auth_state.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_manager.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';
import 'package:bizbrain/features/data_sources/data/remote/data_source_remote_storage.dart';
import 'package:bizbrain/features/data_sources/data/remote/firestore_data_source_remote_storage.dart';
import 'package:bizbrain/features/data_sources/data/remote/noop_data_source_remote_storage.dart';
import 'package:bizbrain/features/data_sources/presentation/providers/google_sheets_providers.dart';
import 'package:bizbrain/features/organizations/presentation/providers/organization_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cloud persistence for connected data sources: Firestore when Firebase is
/// ready and the session is a real signed-in user, no-op otherwise (guest
/// mode / unconfigured builds).
final Provider<DataSourceRemoteStorage> dataSourceRemoteStorageProvider =
    Provider<DataSourceRemoteStorage>((ref) {
      final ready = ref.watch(
        firebaseInitializationProvider.select((initialization) =>
            initialization.isReady),
      );
      final guest = ref.watch(
        authControllerProvider.select(
          (state) => state.status == AuthStatus.guest,
        ),
      );
      if (!ready || guest) return const NoopDataSourceRemoteStorage();
      return FirestoreDataSourceRemoteStorage();
    });

/// Bridges the local Hive cache and the remote storage.
///
/// Every failure is logged and swallowed so a cloud outage never breaks the
/// local, offline-first data source experience.
class DataSourceSyncService {
  DataSourceSyncService({required this.remote, required this.cache});

  final DataSourceRemoteStorage remote;
  final SheetCacheManager cache;

  Future<void> push(SheetCacheModel model, {required String uid}) async {
    try {
      await remote.push(model, uid: uid);
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Cloud push failed for ${model.sourceId}',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> delete(String sourceId, {required String uid}) async {
    try {
      await remote.delete(sourceId, uid: uid);
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Cloud delete failed for $sourceId',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Merges the user's remote sources into the local cache.
  ///
  /// A local entry wins when it is as fresh or fresher than the remote copy
  /// (last-write-wins by `fetchedAt`); otherwise the remote copy is restored
  /// and re-stamped with the caller's current [organizationId] so it shows up
  /// under the active tenant immediately.
  Future<List<SheetCacheModel>> pull({
    required String uid,
    required String organizationId,
  }) async {
    final List<SheetCacheModel> remoteSources;
    try {
      remoteSources = await remote.pull(
        uid: uid,
        organizationId: organizationId,
      );
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Cloud pull failed for $uid',
        error: error,
        stackTrace: stackTrace,
      );
      return const <SheetCacheModel>[];
    }

    for (final model in remoteSources) {
      final local = await cache.getCached(model.sourceId);
      final localFresh = local != null &&
          local.organizationId == organizationId &&
          !model.fetchedAt.isAfter(local.fetchedAt);
      if (localFresh) continue;
      await cache.saveCache(model);
    }
    return remoteSources;
  }
}

final Provider<DataSourceSyncService> dataSourceSyncProvider =
    Provider<DataSourceSyncService>(
      (ref) => DataSourceSyncService(
        remote: ref.read(dataSourceRemoteStorageProvider),
        cache: ref.read(sheetCacheManagerProvider),
      ),
    );

/// Remembers which (uid, organization) pairs have been pulled this session so
/// the bootstrap provider only fetches once per login.
class DataSourceSyncBootstrap {
  final Set<String> _pulled = <String>{};

  Future<void> run({
    required DataSourceSyncService sync,
    required String uid,
    required String organizationId,
    required void Function(String organizationId) onPulled,
  }) async {
    final key = '$uid|$organizationId';
    if (!_pulled.add(key)) return;
    await sync.pull(uid: uid, organizationId: organizationId);
    try {
      onPulled(organizationId);
    } catch (_) {
      // The provider may already be disposed; the pull itself already wrote
      // to Hive, and the manual "Sync cloud" action covers a refetch.
    }
  }
}

final Provider<DataSourceSyncBootstrap>
dataSourceSyncBootstrapControllerProvider = Provider<DataSourceSyncBootstrap>(
  (ref) => DataSourceSyncBootstrap(),
);

/// Restores the signed-in user's data sources into the local cache once per
/// (uid, organization) pair. Watched from the app shell so it runs right
/// after a login (or app start with a persisted session).
final Provider<void> dataSourceSyncBootstrapProvider = Provider<void>((ref) {
  final uid = ref.watch(
    authControllerProvider.select((state) => state.user?.uid),
  );
  final organizationId = ref.watch(
    effectiveOrganizationProvider.select((organization) => organization?.id),
  );
  if (uid == null || organizationId == null || organizationId.isEmpty) return;

  final controller = ref.read(dataSourceSyncBootstrapControllerProvider);
  final sync = ref.read(dataSourceSyncProvider);
  unawaited(
    controller.run(
      sync: sync,
      uid: uid,
      organizationId: organizationId,
      onPulled: (org) => ref.invalidate(sourcesListProvider(org)),
    ),
  );
});