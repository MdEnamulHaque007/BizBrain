import 'package:bizbrain/core/errors/error_mapper.dart';
import 'package:bizbrain/core/utils/responsive.dart';
import 'package:bizbrain/core/widgets/state_views.dart';
import 'package:bizbrain/features/authentication/presentation/providers/auth_providers.dart';
import 'package:bizbrain/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:bizbrain/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:bizbrain/features/dashboard/presentation/widgets/dashboard_section_card.dart';
import 'package:bizbrain/features/organizations/presentation/providers/organization_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dashboard home: aggregates the sections BizBrain AI knows about today.
///
/// Every tile states its real status - live data, empty, or "not available"
/// while the underlying backend service is still missing. No placeholder
/// metrics are ever rendered.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(dashboardSummaryProvider);
    final activeOrganization = ref.watch(activeOrganizationProvider);
    final user = ref.watch(
      authControllerProvider.select((state) => state.user),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppBreakpoints.contentMaxWidth,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Business overview', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              [
                if (user != null) 'Signed in as ${user.friendlyName}',
                if (activeOrganization != null)
                  'Active organization: ${activeOrganization.name}'
                else
                  'No active organization',
              ].join(' · '),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            summary.when(
              loading: () => _Grid(
                sections: const <DashboardSection>[
                  DashboardSection(
                    id: DashboardSectionId.organizations,
                    status: DashboardSectionStatus.loading,
                  ),
                  DashboardSection(
                    id: DashboardSectionId.dataSources,
                    status: DashboardSectionStatus.loading,
                  ),
                  DashboardSection(
                    id: DashboardSectionId.aiInsights,
                    status: DashboardSectionStatus.loading,
                  ),
                  DashboardSection(
                    id: DashboardSectionId.businessAlerts,
                    status: DashboardSectionStatus.loading,
                  ),
                  DashboardSection(
                    id: DashboardSectionId.pendingApprovals,
                    status: DashboardSectionStatus.loading,
                  ),
                  DashboardSection(
                    id: DashboardSectionId.recentActivity,
                    status: DashboardSectionStatus.loading,
                  ),
                ],
              ),
              error: (error, _) => ErrorStateView(
                title: ErrorMapper.isPermissionDenied(error)
                    ? 'Access denied'
                    : 'Something went wrong',
                message: ErrorMapper.messageFor(error),
                onRetry: () => ref.invalidate(dashboardSummaryProvider),
              ),
              data: (data) => _Grid(sections: data.sections),
            ),
          ],
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.sections});

  final List<DashboardSection> sections;

  @override
  Widget build(BuildContext context) {
    final columns = AppBreakpoints.dashboardColumns(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisExtent: 170,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: sections.length,
      itemBuilder: (context, index) =>
          DashboardSectionCard(section: sections[index]),
    );
  }
}
