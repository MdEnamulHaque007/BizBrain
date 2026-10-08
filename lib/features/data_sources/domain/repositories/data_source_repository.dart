import 'package:bizbrain/features/data_sources/domain/entities/data_source.dart';

/// Read contract for data source connections.
///
/// Connecting, syncing and credential handling all run through trusted
/// backend services (Phase 02): OAuth secrets, API keys and service accounts
/// must never be stored in, or processed by, the Flutter client.
abstract interface class DataSourceRepository {
  /// Data sources of a single tenant. Implementations must scope every read
  /// by [organizationId] to preserve tenant isolation.
  Stream<List<DataSource>> watchForOrganization(String organizationId);
}
