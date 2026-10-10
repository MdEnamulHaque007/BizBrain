import 'dart:convert';

import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';

/// Maximum number of rows persisted to a remote document.
const int kRemoteMaxStoredRows = 500;

/// Maximum JSON byte size of the stored rows payload (Firestore documents
/// are capped at 1 MB; the budget leaves room for columns and metadata).
const int kRemoteMaxStoredRowBytes = 400 * 1024;

/// Returns [model] with `rows` reduced so the payload stays within
/// [maxRows] entries and [maxBytes] of JSON.
///
/// `rowCount` keeps the total number of rows actually fetched, so callers can
/// detect truncation as `rows.length < rowCount`. Everything else in the
/// model (config, columns, counts) is preserved untouched.
SheetCacheModel capRowsForRemote(
  SheetCacheModel model, {
  int maxRows = kRemoteMaxStoredRows,
  int maxBytes = kRemoteMaxStoredRowBytes,
}) {
  final kept = <Map<String, String>>[];
  var bytes = 0;
  for (final row in model.rows) {
    if (kept.length >= maxRows) break;
    final size = utf8.encode(jsonEncode(row)).length + 1;
    if (bytes + size > maxBytes) break;
    kept.add(row);
    bytes += size;
  }
  if (kept.length == model.rows.length) return model;
  return model.copyWith(rows: kept);
}

/// Persistent store for connected data sources, scoped to a signed-in user.
///
/// The local Hive cache stays the fast, offline-first layer; this interface
/// is the cross-device layer that survives sign-out: after logging in again
/// with the same account the user's sources are restored from here.
abstract class DataSourceRemoteStorage {
  /// Creates or overwrites the remote document for [model] (rows capped).
  Future<void> push(SheetCacheModel model, {required String uid});

  /// Removes the remote document for [sourceId] if it exists.
  Future<void> delete(String sourceId, {required String uid});

  /// All remote sources of [uid], re-stamped to [organizationId] so they land
  /// in the caller's current tenant scope.
  Future<List<SheetCacheModel>> pull({
    required String uid,
    required String organizationId,
  });
}
