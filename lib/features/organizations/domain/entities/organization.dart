/// Lifecycle of an organization document.
///
/// `pendingProvisioning` documents may exist while a backend job finishes
/// creating the tenant; they are never writable by clients.
enum OrganizationStatus { active, suspended, pendingProvisioning }

/// A tenant of BizBrain AI: an independent company (or group) that owns its
/// own factories, departments, data sources and insights.
class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.memberIds,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String name;

  /// User id of the founding member. Immutable after creation and only ever
  /// written by the trusted backend.
  final String ownerId;

  /// Denormalized membership list.
  ///
  /// Security rules require `request.auth.uid in resource.data.memberIds`
  /// for reads, which is what makes tenant isolation provable for both single
  /// document reads and `arrayContains` list queries.
  final List<String> memberIds;

  final OrganizationStatus status;
  final DateTime createdAt;

  int get memberCount => memberIds.length;

  bool containsMember(String userId) => memberIds.contains(userId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Organization && other.id == id && other.name == name);

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() =>
      'Organization(id: $id, status: $status, members: $memberCount)';
}
