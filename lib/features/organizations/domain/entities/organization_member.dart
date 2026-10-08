/// Role of a single user inside an organization.
///
/// Roles are assigned by the trusted backend only; the client is never
/// allowed to write them (see `firestore.rules`).
enum OrganizationRole { owner, admin, manager, member, viewer }

/// Membership lifecycle.
enum MemberStatus { active, invited, suspended }

/// A user's membership document under
/// `organizations/{organizationId}/members/{userId}`.
class OrganizationMember {
  const OrganizationMember({
    required this.organizationId,
    required this.userId,
    required this.role,
    required this.status,
    required this.joinedAt,
  });

  final String organizationId;
  final String userId;
  final OrganizationRole role;
  final MemberStatus status;
  final DateTime joinedAt;

  bool get isActive => status == MemberStatus.active;

  /// Privileged roles; used to decide whether UI should offer management
  /// actions once the backend supports them.
  bool get isPrivileged =>
      role == OrganizationRole.owner || role == OrganizationRole.admin;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrganizationMember &&
          other.organizationId == organizationId &&
          other.userId == userId &&
          other.role == role);

  @override
  int get hashCode => Object.hash(organizationId, userId, role);

  @override
  String toString() =>
      'OrganizationMember(org: $organizationId, role: $role, status: $status)';
}
