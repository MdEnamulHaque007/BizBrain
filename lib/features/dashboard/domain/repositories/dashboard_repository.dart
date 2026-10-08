import 'package:bizbrain/features/dashboard/domain/entities/dashboard_summary.dart';

/// Produces the data shown on the dashboard.
///
/// Phase 01 aggregates only what can be read with the client SDK (the user's
/// organizations). Everything that depends on backend services is reported as
/// [DashboardSectionStatus.unavailable] instead of being invented.
abstract interface class DashboardRepository {
  Stream<DashboardSummary> watchSummary({required String userId});
}
