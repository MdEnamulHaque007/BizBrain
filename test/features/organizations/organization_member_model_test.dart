import 'package:bizbrain/features/organizations/data/models/organization_member_model.dart';
import 'package:bizbrain/features/organizations/domain/entities/organization_member.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final joinedAt = DateTime.utc(2026, 1, 2, 3, 4, 5);

  Map<String, dynamic> validMap({
    Object? userId = 'user-1',
    Object? role = 'owner',
    Object? status = 'active',
    Object? joinedAtValue,
  }) => <String, dynamic>{
    'userId': ?userId,
    'role': role,
    'status': status,
    'joinedAt': joinedAtValue ?? Timestamp.fromDate(joinedAt),
  };

  OrganizationMemberModel build() => OrganizationMemberModel(
    organizationId: 'org-1',
    userId: 'user-1',
    role: OrganizationRole.owner,
    status: MemberStatus.active,
    joinedAt: joinedAt,
  );

  group('OrganizationMemberModel serialization', () {
    test('toMap includes userId alongside role, status and joinedAt', () {
      final map = build().toMap();

      expect(map['userId'], 'user-1');
      expect(map['role'], 'owner');
      expect(map['status'], 'active');
      expect(map['joinedAt'], Timestamp.fromDate(joinedAt));
      expect(map.keys.toList()..sort(), [
        'joinedAt',
        'role',
        'status',
        'userId',
      ]);
    });
  });

  group('OrganizationMemberModel deserialization', () {
    test('fromMap maps a matching userId field', () {
      final model = OrganizationMemberModel.fromMap(
        validMap(),
        organizationId: 'org-1',
        userId: 'user-1',
      );

      expect(model.userId, 'user-1');
      expect(model.organizationId, 'org-1');
      expect(model.role, OrganizationRole.owner);
      expect(model.status, MemberStatus.active);
      expect(model.joinedAt.isAtSameMomentAs(joinedAt), isTrue);
    });

    test('fromMap rejects a userId that does not match the path', () {
      expect(
        () => OrganizationMemberModel.fromMap(
          validMap(userId: 'someone-else'),
          organizationId: 'org-1',
          userId: 'user-1',
        ),
        throwsFormatException,
      );
    });

    test('fromMap accepts legacy documents without a userId field', () {
      // Compatibility: no fabrication - the document path remains the
      // identity source when the field is absent.
      final model = OrganizationMemberModel.fromMap(
        validMap(userId: null),
        organizationId: 'org-1',
        userId: 'user-1',
      );

      expect(model.userId, 'user-1');
      expect(model.role, OrganizationRole.owner);
      expect(model.status, MemberStatus.active);
    });

    test('fromMap keeps existing role and status mapping behavior', () {
      final viewer = OrganizationMemberModel.fromMap(
        validMap(role: 'viewer', status: 'invited'),
        organizationId: 'org-1',
        userId: 'user-1',
      );
      expect(viewer.role, OrganizationRole.viewer);
      expect(viewer.status, MemberStatus.invited);

      final suspended = OrganizationMemberModel.fromMap(
        validMap(role: 'member', status: 'suspended'),
        organizationId: 'org-1',
        userId: 'user-1',
      );
      expect(suspended.role, OrganizationRole.member);
      expect(suspended.status, MemberStatus.suspended);

      expect(
        () => OrganizationMemberModel.fromMap(
          validMap(role: 'superuser'),
          organizationId: 'org-1',
          userId: 'user-1',
        ),
        throwsFormatException,
      );
      expect(
        () => OrganizationMemberModel.fromMap(
          validMap(status: 'banned'),
          organizationId: 'org-1',
          userId: 'user-1',
        ),
        throwsFormatException,
      );
      expect(
        () => OrganizationMemberModel.fromMap(
          validMap(role: 42),
          organizationId: 'org-1',
          userId: 'user-1',
        ),
        throwsFormatException,
      );
      expect(
        () => OrganizationMemberModel.fromMap(
          validMap(status: 42),
          organizationId: 'org-1',
          userId: 'user-1',
        ),
        throwsFormatException,
      );
    });

    test('fromMap rejects a non-string userId field', () {
      expect(
        () => OrganizationMemberModel.fromMap(
          validMap(userId: 7),
          organizationId: 'org-1',
          userId: 'user-1',
        ),
        throwsFormatException,
      );
    });
  });
}
