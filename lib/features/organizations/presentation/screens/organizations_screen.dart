import 'package:bizbrain/core/errors/error_mapper.dart';
import 'package:bizbrain/core/widgets/state_views.dart';
import 'package:bizbrain/features/organizations/presentation/providers/organization_providers.dart';
import 'package:bizbrain/features/organizations/presentation/widgets/organization_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tenant overview: lists every organization the signed-in user belongs to
/// and lets them switch the active tenant.
///
/// Organization creation is intentionally absent - provisioning is a
/// backend-mediated operation (see `docs/architecture.md`).
class OrganizationsScreen extends ConsumerWidget {
  const OrganizationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final organizations = ref.watch(myOrganizationsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Organizations', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Each organization is a separate tenant with its own factories, '
              'departments, data sources and insights. Select one to make it active.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Organization provisioning runs on trusted backend services that are '
                        'not deployed yet, so new tenants cannot be created from the client. '
                        'Membership and roles are never writable from this app.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            organizations.when(
              loading: () =>
                  const LoadingStateView(message: 'Loading organizations...'),
              error: (error, _) => ErrorStateView(
                message: ErrorMapper.messageFor(error),
                onRetry: () => ref.invalidate(myOrganizationsProvider),
              ),
              data: (items) => items.isEmpty
                  ? EmptyStateView(
                      icon: Icons.domain_outlined,
                      title: 'No organizations yet',
                      message:
                          'You are not a member of any organization. An administrator '
                          'will grant you access once your tenant is provisioned.',
                    )
                  : Column(
                      children: [
                        for (final organization in items) ...[
                          OrganizationCard(organization: organization),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
