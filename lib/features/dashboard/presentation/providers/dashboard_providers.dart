import 'package:bizbrain/features/authentication/presentation/providers/auth_providers.dart';
import 'package:bizbrain/features/dashboard/data/repositories/aggregating_dashboard_repository.dart';
import 'package:bizbrain/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:bizbrain/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:bizbrain/features/organizations/presentation/providers/organization_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<DashboardRepository> dashboardRepositoryProvider =
    Provider<DashboardRepository>((Ref ref) {
      return AggregatingDashboardRepository(
        organizations: ref.watch(organizationRepositoryProvider),
      );
    });

/// Honest dashboard for sessions without a user (guest demo mode): no tile
/// claims data it does not have - the organization tile reports zero loaded
/// organizations and every other tile keeps its "not built yet" note.
const DashboardSummary _guestSummary = DashboardSummary(
  sections: <DashboardSection>[
    DashboardSection(
      id: DashboardSectionId.organizations,
      status: DashboardSectionStatus.empty,
      count: 0,
      note: 'Guest demo mode: sign in to load organization data.',
    ),
    DashboardSection(
      id: DashboardSectionId.dataSources,
      status: DashboardSectionStatus.unavailable,
      note: 'External data connectors arrive in Phase 02.',
    ),
    DashboardSection(
      id: DashboardSectionId.aiInsights,
      status: DashboardSectionStatus.unavailable,
      note: 'AI analysis runs on backend services that are not deployed yet.',
    ),
    DashboardSection(
      id: DashboardSectionId.businessAlerts,
      status: DashboardSectionStatus.unavailable,
      note: 'Risk and anomaly detection arrives with the AI engine.',
    ),
    DashboardSection(
      id: DashboardSectionId.pendingApprovals,
      status: DashboardSectionStatus.unavailable,
      note: 'Approval workflows require the backend automation service.',
    ),
    DashboardSection(
      id: DashboardSectionId.recentActivity,
      status: DashboardSectionStatus.unavailable,
      note:
          'Activity logging starts once backend services write audit entries.',
    ),
  ],
);

/// Live dashboard data for the signed-in user.
///
/// Without a user (guest mode) the summary is emitted immediately so tiles
/// settle into their honest empty/unavailable state instead of spinning.
final StreamProvider<DashboardSummary>
dashboardSummaryProvider = StreamProvider<DashboardSummary>((Ref ref) {
  final user = ref.watch(authControllerProvider.select((state) => state.user));
  if (user == null) return Stream<DashboardSummary>.value(_guestSummary);
  return ref.watch(dashboardRepositoryProvider).watchSummary(userId: user.uid);
});
