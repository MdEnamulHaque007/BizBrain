import 'package:bizbrain/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:bizbrain/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:bizbrain/features/organizations/domain/entities/organization.dart';
import 'package:bizbrain/features/organizations/domain/repositories/organization_repository.dart';

/// [DashboardRepository] composed from the repositories available in Phase 01.
///
/// The organization tile is fed by real tenant data; the remaining tiles are
/// explicitly marked as unavailable because their backend services do not
/// exist yet.
class AggregatingDashboardRepository implements DashboardRepository {
  AggregatingDashboardRepository({
    required OrganizationRepository organizations,
  }) : _organizations = organizations;

  final OrganizationRepository _organizations;

  @override
  Stream<DashboardSummary> watchSummary({required String userId}) {
    return _organizations.watchUserOrganizations(userId).map(_buildSummary);
  }

  DashboardSummary _buildSummary(List<Organization> organizations) {
    final organizationCount = organizations.length;
    return DashboardSummary(
      sections: <DashboardSection>[
        DashboardSection(
          id: DashboardSectionId.organizations,
          status: organizationCount == 0
              ? DashboardSectionStatus.empty
              : DashboardSectionStatus.ready,
          count: organizationCount,
          note: organizationCount == 0
              ? 'You are not a member of any organization yet.'
              : 'Organizations you can access.',
        ),
        const DashboardSection(
          id: DashboardSectionId.dataSources,
          status: DashboardSectionStatus.unavailable,
          note: 'External data connectors arrive in Phase 02.',
        ),
        const DashboardSection(
          id: DashboardSectionId.aiInsights,
          status: DashboardSectionStatus.unavailable,
          note:
              'AI analysis runs on backend services that are not deployed yet.',
        ),
        const DashboardSection(
          id: DashboardSectionId.businessAlerts,
          status: DashboardSectionStatus.unavailable,
          note: 'Risk and anomaly detection arrives with the AI engine.',
        ),
        const DashboardSection(
          id: DashboardSectionId.pendingApprovals,
          status: DashboardSectionStatus.unavailable,
          note: 'Approval workflows require the backend automation service.',
        ),
        const DashboardSection(
          id: DashboardSectionId.recentActivity,
          status: DashboardSectionStatus.unavailable,
          note:
              'Activity logging starts once backend services write audit entries.',
        ),
      ],
    );
  }
}
