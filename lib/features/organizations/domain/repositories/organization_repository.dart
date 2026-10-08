import 'package:bizbrain/features/organizations/domain/entities/organization.dart';
import 'package:bizbrain/features/organizations/domain/entities/organization_member.dart';

/// Read contracts for organization data.
///
/// Deliberately read-only: creating organizations and assigning roles are
/// privileged operations that will be exposed through trusted backend
/// endpoints (Cloud Functions) in Phase 02. There is no client-side method to
/// create a tenant or to grant yourself a role, and the security rules deny
/// every write to these collections from the app.
abstract interface class OrganizationRepository {
  /// Organizations the given user is a member of.
  ///
  /// Implementations MUST filter by membership (Firestore:
  /// `where('memberIds', arrayContains: userId)`), which both satisfies the
  /// security rules and guarantees no cross-tenant leakage.
  Stream<List<Organization>> watchUserOrganizations(String userId);

  /// Single organization lookup; `null` when it does not exist.
  ///
  /// Throws a permission error when the caller is not a member.
  Future<Organization?> fetchOrganization(String organizationId);

  /// The caller's own membership document, or `null` when none exists.
  Stream<OrganizationMember?> watchMembership({
    required String organizationId,
    required String userId,
  });
}
