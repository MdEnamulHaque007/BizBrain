import 'package:bizbrain/core/constants/firestore_collections.dart';
import 'package:bizbrain/core/logging/app_logger.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'data_source_remote_storage.dart';

/// Firestore-backed persistence for connected data sources.
///
/// Documents live at `users/{uid}/dataSources/{sourceId}`, so the security
/// rules only need the path variable to prove ownership and a single `get`
/// on the collection restores every source of a signed-in account - the
/// "log in with the same email and everything is back" behaviour.
///
/// Rows are capped by [capRowsForRemote] so a document can never approach
/// the 1 MB Firestore limit.
class FirestoreDataSourceRemoteStorage implements DataSourceRemoteStorage {
  FirestoreDataSourceRemoteStorage({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  late final FirebaseFirestore _firestore =
      _firestoreOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _sources(String uid) =>
      _firestore
          .collection(FirestoreCollections.users)
          .doc(uid)
          .collection(FirestoreCollections.dataSources);

  @override
  Future<void> push(SheetCacheModel model, {required String uid}) async {
    final capped = capRowsForRemote(model);
    await _sources(uid).doc(model.sourceId).set(<String, dynamic>{
      'uid': uid,
      'updatedAt': capped.fetchedAt.toIso8601String(),
      ...capped.toJson(),
    });
    AppLogger.info(
      'Pushed data source ${model.sourceId} to the cloud '
      '(${capped.rows.length}/${model.rowCount} rows stored)',
    );
  }

  @override
  Future<void> delete(String sourceId, {required String uid}) =>
      _sources(uid).doc(sourceId).delete();

  @override
  Future<List<SheetCacheModel>> pull({
    required String uid,
    required String organizationId,
  }) async {
    final snapshot = await _sources(uid).get();
    final models = <SheetCacheModel>[];
    for (final document in snapshot.docs) {
      try {
        models.add(
          SheetCacheModel.fromJson(
            document.data(),
          ).copyWith(organizationId: organizationId),
        );
      } catch (error, stackTrace) {
        AppLogger.warning(
          'Skipping malformed remote data source ${document.id}',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    return models;
  }
}
