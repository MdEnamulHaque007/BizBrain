/// Contract for connecting to an external business system (ERP, database,
/// spreadsheet, REST API, ...).
///
/// Implementations live on the backend (Cloud Run workers / Cloud Functions).
/// The Flutter client only ever talks to authenticated backend endpoints -
/// connector credentials and raw payloads must never transit the app.
abstract interface class ExternalDataConnector {
  /// Stable identifier of this connector type, e.g. `odoo`, `postgres`.
  String get typeId;

  /// Verifies that the backend can reach the external system.
  Future<ConnectionTestResult> testConnection(ConnectionConfig config);

  /// Pulls records changed since [since], streaming progress to the caller.
  Stream<ConnectorSyncEvent> sync({
    required ConnectionConfig config,
    required DateTime since,
  });
}

/// Connection parameters handled by the backend. [settings] must never
/// contain client-side secrets; credentials are resolved server-side from
/// a secret manager using [credentialRef].
class ConnectionConfig {
  const ConnectionConfig({
    required this.organizationId,
    required this.endpoint,
    this.credentialRef,
    this.settings = const <String, String>{},
  });

  final String organizationId;
  final String endpoint;

  /// Reference (not the value) to a secret stored in Secret Manager.
  final String? credentialRef;
  final Map<String, String> settings;
}

class ConnectionTestResult {
  const ConnectionTestResult({required this.success, this.message});

  final bool success;
  final String? message;
}

class ConnectorSyncEvent {
  const ConnectorSyncEvent({
    required this.recordsProcessed,
    required this.finished,
    this.error,
  });

  final int recordsProcessed;
  final bool finished;
  final String? error;
}
