import 'package:bizbrain/core/constants/firestore_collections.dart';
import 'package:bizbrain/core/logging/app_logger.dart';
import 'package:bizbrain/features/organizations/data/models/organization_member_model.dart';
import 'package:bizbrain/features/organizations/data/models/organization_model.dart';
import 'package:bizbrain/features/organizations/domain/entities/organization.dart';
import 'package:bizbrain/features/organizations/domain/entities/organization_member.dart';
import 'package:bizbrain/features/organizations/domain/repositories/organization_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore implementation of [OrganizationRepository].
///
/// All reads are membership-scoped; there is no code path that writes to the
/// organization or membership collections.
class FirestoreOrganizationRepository implements OrganizationRepository {
  FirestoreOrganizationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _organizations =>
      _firestore.collection(FirestoreCollections.organizations);

  @override
  Stream<List<Organization>> watchUserOrganizations(String userId) {
    // Secure listing (Micro Step 1.6.15): the membership document is the
    // source of truth, so the stream starts from a collection-group query
    // over `members` filtered to this user's ACTIVE memberships. The strict
    // organization `get` rule then re-authorizes every document individually
    // (`memberIds` alone is never used as the authorization source, and the
    // `organizations` collection is never listed directly).
    //
    // NOTE: organization document changes are only reflected after the next
    // membership snapshot - a membership refresh may be required until a
    // dedicated reactive design (e.g. combining per-organization streams)
    // is implemented.
    return _firestore
        .collectionGroup(FirestoreCollections.members)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: MemberStatus.active.name)
        .snapshots()
        .asyncMap((memberships) async {
          final organizationIds = <String>{};
          for (final membership in memberships.docs) {
            final organizationId = _organizationIdFromMembershipPath(
              membership.reference.path,
            );
            if (organizationId == null) {
              AppLogger.warning(
                'Skipping membership with unexpected path '
                '${membership.reference.path}',
              );
              continue;
            }
            organizationIds.add(organizationId);
          }

          final organizations = <Organization>[];
          for (final organizationId in organizationIds) {
            try {
              final document = await _organizations.doc(organizationId).get();
              if (!document.exists) continue;
              final organization = OrganizationModel.fromMap(
                document.data()!,
                id: document.id,
              );
              if (organization.status != OrganizationStatus.active) continue;
              organizations.add(organization);
            } on FirebaseException catch (error) {
              if (error.code == 'permission-denied') {
                // The strict rules denied this document: it must never
                // appear in results.
                AppLogger.info(
                  'Organization $organizationId denied by security rules',
                );
                continue;
              }
              // Any other Firestore error is infrastructure trouble and is
              // surfaced to the caller instead of silently swallowed.
              rethrow;
            } on FormatException catch (error, stackTrace) {
              AppLogger.warning(
                'Skipping malformed organization document $organizationId',
                error: error,
                stackTrace: stackTrace,
              );
            }
          }

          organizations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return List<Organization>.unmodifiable(organizations);
        });
  }

  /// Extracts the organization id from a membership document path such as
  /// `organizations/org-1/members/user-1`.
  ///
  /// Returns `null` for unexpected shapes - a missing or malformed id is
  /// skipped rather than fabricated.
  static String? _organizationIdFromMembershipPath(String path) {
    final segments = path.split('/');
    if (segments.length != 4 ||
        segments[0] != FirestoreCollections.organizations ||
        segments[2] != FirestoreCollections.members ||
        segments[1].isEmpty) {
      return null;
    }
    return segments[1];
  }

  @override
  Future<Organization?> fetchOrganization(String organizationId) async {
    final snapshot = await _organizations.doc(organizationId).get();
    if (!snapshot.exists) return null;
    return OrganizationModel.fromMap(snapshot.data()!, id: snapshot.id);
  }

  @override
  Stream<OrganizationMember?> watchMembership({
    required String organizationId,
    required String userId,
  }) {
    return _organizations
        .doc(organizationId)
        .collection(FirestoreCollections.members)
        .doc(userId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (!snapshot.exists || data == null) return null;
          try {
            return OrganizationMemberModel.fromMap(
              data,
              organizationId: organizationId,
              userId: userId,
            );
          } catch (error, stackTrace) {
            AppLogger.warning(
              'Skipping malformed membership document $organizationId/$userId',
              error: error,
              stackTrace: stackTrace,
            );
            return null;
          }
        });
  }
}
