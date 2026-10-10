import 'dart:async';

import 'package:bizbrain/core/errors/error_mapper.dart';
import 'package:bizbrain/core/widgets/state_views.dart';
import 'package:bizbrain/features/organizations/domain/entities/organization.dart';
import 'package:bizbrain/features/organizations/presentation/providers/organization_providers.dart';
import 'package:bizbrain/features/organizations/presentation/widgets/organization_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tenant overview: lists every organization the signed-in user belongs to
/// and lets them switch the active tenant.
///
/// When the backend has no tenants (provisioning not deployed / slow), a
/// virtual personal workspace keeps the screen usable instead of spinning
/// forever; never an infinite loading state.
class OrganizationsScreen extends ConsumerStatefulWidget {
  const OrganizationsScreen({super.key});

  @override
  ConsumerState<OrganizationsScreen> createState() =>
      _OrganizationsScreenState();
}

class _OrganizationsScreenState extends ConsumerState<OrganizationsScreen> {
  static const _loadingTimeout = Duration(seconds: 5);

  bool _timedOut = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_loadingTimeout, () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final organizations = ref.watch(myOrganizationsProvider);
    final effective = ref.watch(effectiveOrganizationProvider);

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
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            _ProvisioningNoticeCard(theme: theme, colorScheme: colorScheme),
            const SizedBox(height: 20),
            organizations.when(
              loading: () => _timedOut
                  ? _fallbackList(theme, colorScheme, effective)
                  : const LoadingStateView(message: 'Loading organizations...'),
              error: (error, _) => ErrorStateView(
                message: ErrorMapper.messageFor(error),
                onRetry: () {
                  if (mounted) setState(() => _timedOut = false);
                  _timer?.cancel();
                  _timer = Timer(_loadingTimeout, () {
                    if (mounted) setState(() => _timedOut = true);
                  });
                  ref.invalidate(myOrganizationsProvider);
                },
              ),
              data: (items) => items.isEmpty
                  ? _fallbackList(theme, colorScheme, effective)
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

  /// Personal-workspace fallback card plus a hint when the backend has zero
  /// tenants. Replaces the old "No organizations yet" dead end.
  Widget _fallbackList(
    ThemeData theme,
    ColorScheme colorScheme,
    Organization? effective,
  ) {
    if (effective == null) {
      return const EmptyStateView(
        icon: Icons.person_outline,
        title: 'Sign in to get a personal workspace',
        message: 'A personal workspace is created for your account '
            'until organizations become available.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PersonalWorkspaceCard(theme: theme, colorScheme: colorScheme),
      ],
    );
  }
}

class _ProvisioningNoticeCard extends StatelessWidget {
  const _ProvisioningNoticeCard({
    required this.theme,
    required this.colorScheme,
  });

  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 20,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Organization provisioning requires backend deployment. '
                    'Contact admin.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.add_business_outlined),
                    label: const Text('Create Organization'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonalWorkspaceCard extends StatelessWidget {
  const _PersonalWorkspaceCard({
    required this.theme,
    required this.colorScheme,
  });

  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.primary,
              child: Icon(Icons.person, color: colorScheme.onPrimary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Personal',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const _ActiveChip(),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your personal workspace · created automatically until an '
                    'organization is provisioned',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  const _ActiveChip();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Active',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}