import 'package:bizbrain/features/organizations/domain/entities/organization_member.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore representation of [OrganizationMember].
class OrganizationMemberModel extends OrganizationMember {
  const OrganizationMemberModel({
    required super.organizationId,
    required super.userId,
    required super.role,
    required super.status,
    required super.joinedAt,
  });

  factory OrganizationMemberModel.fromMap(
    Map<String, dynamic> map, {
    required String organizationId,
    required String userId,
  }) {
    final rawRole = map['role'];
    if (rawRole is! String) {
      throw const FormatException('Membership document is missing "role".');
    }
    final rawStatus = map['status'];
    if (rawStatus is! String) {
      throw const FormatException('Membership document is missing "status".');
    }

    // The stored `userId` field backs the secure collection-group membership
    // query (the rules engine proves `request.auth.uid == resource.data
    // .userId`), so a present value must match the document path - a
    // mismatched one is corrupt or tampered with and never trusted. Legacy
    // documents without the field still parse: the document path stays the
    // identity source, and no userId is fabricated from other data.
    final storedUserId = map['userId'];
    if (storedUserId != null) {
      if (storedUserId is! String) {
        throw const FormatException(
          'Membership document "userId" must be a string.',
        );
      }
      if (storedUserId != userId) {
        throw const FormatException(
          'Membership document "userId" does not match its document path.',
        );
      }
    }

    return OrganizationMemberModel(
      organizationId: organizationId,
      userId: userId,
      role: parseRole(rawRole),
      status: parseStatus(rawStatus),
      joinedAt: _parseJoinedAt(map['joinedAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'userId': userId,
    'role': role.name,
    'status': status.name,
    'joinedAt': Timestamp.fromDate(joinedAt),
  };

  /// Rejects unknown roles instead of defaulting to a permissive one - a
  /// forwarded future role must never silently escalate privileges client-side.
  static OrganizationRole parseRole(String raw) {
    for (final value in OrganizationRole.values) {
      if (value.name == raw) return value;
    }
    throw FormatException('Unsupported organization role "$raw".');
  }

  static MemberStatus parseStatus(String raw) {
    for (final value in MemberStatus.values) {
      if (value.name == raw) return value;
    }
    throw FormatException('Unsupported member status "$raw".');
  }

  static DateTime _parseJoinedAt(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw const FormatException(
      'Membership document has an invalid "joinedAt".',
    );
  }
}
