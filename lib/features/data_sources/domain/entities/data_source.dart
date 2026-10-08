/// Kind of external system a data source connects to.
enum DataSourceKind { erp, database, spreadsheet, restApi, fileUpload, other }

/// Connection lifecycle of a data source.
enum DataSourceConnectionStatus { disconnected, connecting, connected, error }

/// A connection between BizBrain AI and an external business system.
class DataSource {
  const DataSource({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.kind,
    required this.status,
    this.lastSyncedAt,
  });

  final String id;
  final String organizationId;
  final String name;
  final DataSourceKind kind;
  final DataSourceConnectionStatus status;
  final DateTime? lastSyncedAt;

  @override
  String toString() => 'DataSource($id, $kind, $status)';
}
