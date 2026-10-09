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
/// Only real status from the dashboard provider is shown; no placeholder metrics.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final summary = ref.watch(dashboardSummaryProvider);
    final activeOrganization = ref.watch(activeOrganizationProvider);
    final user = ref.watch(
      authControllerProvider.select((state) => state.user),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.contentMaxWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary,
                      Color.lerp(colors.primary, colors.tertiary, 0.58)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: colors.onPrimary.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: colors.onPrimary,
                            size: 27,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'BizBrain overview',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: colors.onPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your business, organized in one place.',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.onPrimary.withValues(alpha: 0.96),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      [
                        if (user != null) 'Signed in as ${user.friendlyName}',
                        if (activeOrganization != null)
                          'Active organization: ${activeOrganization.name}'
                        else
                          'No active organization selected',
                      ].join('  •  '),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onPrimary.withValues(alpha: 0.86),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Container(
                    width: 5,
                    height: 28,
                    decoration: BoxDecoration(
                      color: colors.tertiary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Workspace status',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(Icons.dashboard_customize_rounded,
                      color: colors.primary),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'A live view of the features and business activity available to you.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
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
