import 'package:bizbrain/features/authentication/presentation/providers/auth_providers.dart';
import 'package:bizbrain/features/organizations/domain/entities/organization.dart';
import 'package:bizbrain/features/organizations/domain/entities/organization_member.dart';
import 'package:bizbrain/features/organizations/presentation/providers/organization_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Single organization row: identity, status, the caller's role and the
/// "make active" control used for tenant selection.
class OrganizationCard extends ConsumerWidget {
  const OrganizationCard({super.key, required this.organization});

  final Organization organization;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isActive = ref.watch(
      activeOrganizationProvider.select(
        (active) => active?.id == organization.id,
      ),
    );
    final membership = ref.watch(_membershipProvider(organization.id));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.business,
                size: 20,
                color: isActive
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
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
                          organization.name,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusChip(status: organization.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${organization.memberCount} member${organization.memberCount == 1 ? '' : 's'}'
                    ' · created ${_formatDate(organization.createdAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  membership.when(
                    data: (member) => member == null
                        ? Text(
                            'No membership document for your account.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          )
                        : Wrap(
                            spacing: 8,
                            children: [
                              Chip(
                                avatar: const Icon(
                                  Icons.badge_outlined,
                                  size: 16,
                                ),
                                label: Text(_roleLabel(member.role)),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                    loading: () => Text(
                      'Loading membership...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    error: (_, _) => Text(
                      'Membership unavailable',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            isActive
                ? Chip(
                    avatar: Icon(
                      Icons.check_circle,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    label: const Text('Active'),
                    visualDensity: VisualDensity.compact,
                  )
                : TextButton.icon(
                    onPressed: () => ref
                        .read(selectedOrganizationIdProvider.notifier)
                        .select(organization.id),
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('Make active'),
                  ),
          ],
        ),
      ),
    );
  }

  static String _roleLabel(OrganizationRole role) {
    switch (role) {
      case OrganizationRole.owner:
        return 'Owner';
      case OrganizationRole.admin:
        return 'Administrator';
      case OrganizationRole.manager:
        return 'Manager';
      case OrganizationRole.member:
        return 'Member';
      case OrganizationRole.viewer:
        return 'Viewer';
    }
  }

  static String _formatDate(DateTime value) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }
}

/// Small tinted badge describing an organization's lifecycle status.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final OrganizationStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (status) {
      OrganizationStatus.active => ('Active', theme.colorScheme.primary),
      OrganizationStatus.suspended => ('Suspended', theme.colorScheme.error),
      OrganizationStatus.pendingProvisioning => (
        'Provisioning',
        theme.colorScheme.tertiary,
      ),
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

/// Membership of the *current user* inside one organization.
final _membershipProvider = StreamProvider.autoDispose
    .family<OrganizationMember?, String>((Ref ref, String organizationId) {
      final userId = ref.watch(
        authControllerProvider.select((state) => state.user?.uid),
      );
      if (userId == null) return const Stream<OrganizationMember?>.empty();
      return ref
          .watch(organizationRepositoryProvider)
          .watchMembership(organizationId: organizationId, userId: userId);
    });
