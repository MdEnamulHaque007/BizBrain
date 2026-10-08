import 'package:bizbrain/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:flutter/material.dart';

/// Presentation metadata for each dashboard tile.
class DashboardSectionMeta {
  const DashboardSectionMeta({required this.title, required this.icon});

  final String title;
  final IconData icon;
}

DashboardSectionMeta dashboardSectionMeta(DashboardSectionId id) {
  switch (id) {
    case DashboardSectionId.organizations:
      return const DashboardSectionMeta(
        title: 'Active organizations',
        icon: Icons.business_outlined,
      );
    case DashboardSectionId.dataSources:
      return const DashboardSectionMeta(
        title: 'Connected data sources',
        icon: Icons.cable_outlined,
      );
    case DashboardSectionId.aiInsights:
      return const DashboardSectionMeta(
        title: 'AI insights',
        icon: Icons.auto_awesome_outlined,
      );
    case DashboardSectionId.businessAlerts:
      return const DashboardSectionMeta(
        title: 'Business alerts',
        icon: Icons.notifications_active_outlined,
      );
    case DashboardSectionId.pendingApprovals:
      return const DashboardSectionMeta(
        title: 'Pending approvals',
        icon: Icons.fact_check_outlined,
      );
    case DashboardSectionId.recentActivity:
      return const DashboardSectionMeta(
        title: 'Recent activity',
        icon: Icons.history,
      );
  }
}

/// Single dashboard tile. Renders only what the repository reports - never
/// sample metrics.
class DashboardSectionCard extends StatelessWidget {
  const DashboardSectionCard({super.key, required this.section});

  final DashboardSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = dashboardSectionMeta(section.id);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(meta.icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    meta.title,
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: section.status),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: _SectionBody(section: section)),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final DashboardSectionStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (status) {
      DashboardSectionStatus.ready => ('Live', theme.colorScheme.primary),
      DashboardSectionStatus.loading => ('Loading', theme.colorScheme.outline),
      DashboardSectionStatus.empty => ('Empty', theme.colorScheme.outline),
      DashboardSectionStatus.unavailable => (
        'Not available',
        theme.colorScheme.tertiary,
      ),
      DashboardSectionStatus.error => ('Error', theme.colorScheme.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({required this.section});

  final DashboardSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    switch (section.status) {
      case DashboardSectionStatus.loading:
        return const LoadingBody(message: 'Loading...');
      case DashboardSectionStatus.ready:
      case DashboardSectionStatus.empty:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${section.count ?? 0}',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            if (section.note != null)
              Expanded(
                child: Text(
                  section.note!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        );
      case DashboardSectionStatus.unavailable:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.schedule, size: 24, color: theme.colorScheme.outline),
            const SizedBox(height: 8),
            if (section.note != null)
              Expanded(
                child: Text(
                  section.note!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        );
      case DashboardSectionStatus.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 24, color: theme.colorScheme.error),
            const SizedBox(height: 8),
            if (section.errorMessage != null)
              Expanded(
                child: Text(
                  section.errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        );
    }
  }
}

/// Compact inline spinner used inside a tile.
class LoadingBody extends StatelessWidget {
  const LoadingBody({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Text(message, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
