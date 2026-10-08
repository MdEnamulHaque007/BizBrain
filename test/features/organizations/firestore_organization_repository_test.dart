// cloud_firestore marks Query/DocumentSnapshot `@sealed` (package:meta), so
// this hand-rolled noSuchMethod test double triggers that advisory lint.
// ignore_for_file: subtype_of_sealed_class

import 'package:bizbrain/features/organizations/data/repositories/firestore_organization_repository.dart';
import 'package:bizbrain/features/organizations/domain/entities/organization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// One recorded `where(...)` clause.
class _WhereCall {
  _WhereCall(this.field, this.named);

  final Object? field;
  final Map<Symbol, Object?> named;
}

/// Membership collection-group query stand-in.
///
/// Records the filter clauses and serves one document per configured path.
/// Any call other than `where`/`snapshots` fails the test.
class _MembershipQuery implements Query<Map<String, dynamic>> {
  _MembershipQuery(this.membershipPaths);

  final List<String> membershipPaths;
  final List<_WhereCall> whereCalls = <_WhereCall>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #where) {
      whereCalls.add(
        _WhereCall(
          invocation.positionalArguments.first,
          Map<Symbol, Object?>.from(invocation.namedArguments),
        ),
      );
      return this;
    }
    if (invocation.memberName == #snapshots) {
      return Stream<QuerySnapshot<Map<String, dynamic>>>.value(
        _FakeMembershipSnapshot(membershipPaths),
      );
    }
    throw UnimplementedError('Query.${invocation.memberName}');
  }
}

class _FakeMembershipSnapshot implements QuerySnapshot<Map<String, dynamic>> {
  _FakeMembershipSnapshot(this._paths);

  final List<String> _paths;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #docs) {
      return _paths.map(_FakeMembershipDoc.new).toList();
    }
    throw UnimplementedError('QuerySnapshot.${invocation.memberName}');
  }
}

/// Membership document exposing only what the repository reads: its path.
class _FakeMembershipDoc
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _FakeMembershipDoc(this._path);

  final String _path;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #reference) {
      return _FakePathReference(_path);
    }
    if (invocation.memberName == #id) {
      return _path.split('/').last;
    }
    throw UnimplementedError('QueryDocumentSnapshot.${invocation.memberName}');
  }
}

class _FakePathReference implements DocumentReference<Map<String, dynamic>> {
  _FakePathReference(this.path);

  @override
  final String path;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #path) return path;
    throw UnimplementedError('DocumentReference.${invocation.memberName}');
  }
}

/// Stand-in for the `organizations` collection.
///
/// `doc(id).get()` resolves from the configured result map:
/// * a `Map` - the document data (`exists == true`),
/// * `null` - a non-existent document,
/// * an `Exception` - thrown by `get()`.
///
/// `where`/`snapshots` are intentionally unimplemented: listing the
/// `organizations` collection directly must fail the test.
class _OrgCollection implements CollectionReference<Map<String, dynamic>> {
  _OrgCollection(this._results);

  final Map<String, Object?> _results;
  final List<String> requestedIds = <String>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #doc) {
      final id = invocation.positionalArguments.first as String;
      requestedIds.add(id);
      return _FakeOrgReference(this, id);
    }
    throw UnimplementedError('CollectionReference.${invocation.memberName}');
  }
}

class _FakeOrgReference implements DocumentReference<Map<String, dynamic>> {
  _FakeOrgReference(this._collection, this.id);

  final _OrgCollection _collection;

  @override
  final String id;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #get) {
      final result = _collection._results[id];
      if (result == null) {
        return Future<DocumentSnapshot<Map<String, dynamic>>>.value(
          _FakeOrgSnapshot(id, null),
        );
      }
      if (result is Map<String, dynamic>) {
        return Future<DocumentSnapshot<Map<String, dynamic>>>.value(
          _FakeOrgSnapshot(id, result),
        );
      }
      return Future<DocumentSnapshot<Map<String, dynamic>>>.error(result);
    }
    throw UnimplementedError('DocumentReference.${invocation.memberName}');
  }
}

class _FakeOrgSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeOrgSnapshot(this.id, this._data);

  @override
  final String id;
  final Map<String, dynamic>? _data;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #exists) return _data != null;
    if (invocation.memberName == #data) return _data;
    if (invocation.memberName == #id) return id;
    throw UnimplementedError('DocumentSnapshot.${invocation.memberName}');
  }
}

/// Stand-in for `FirebaseFirestore`: routes listing traffic to the
/// membership collection-group query and per-document gets to `_OrgCollection`.
class _RecordingFirebaseFirestore implements FirebaseFirestore {
  _RecordingFirebaseFirestore({
    required _OrgCollection orgCollection,
    required _MembershipQuery membershipQuery,
  }) : _orgCollection = orgCollection,
       _membershipQuery = membershipQuery;

  final _OrgCollection _orgCollection;
  final _MembershipQuery _membershipQuery;
  final List<String> collectionCalls = <String>[];
  String? collectionGroupCall;

  _OrgCollection get orgCollection => _orgCollection;
  _MembershipQuery get membershipQuery => _membershipQuery;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #collection) {
      final path = invocation.positionalArguments.first as String;
      collectionCalls.add(path);
      return _orgCollection;
    }
    if (invocation.memberName == #collectionGroup) {
      collectionGroupCall = invocation.positionalArguments.first as String;
      return _membershipQuery;
    }
    throw UnimplementedError('FirebaseFirestore.${invocation.memberName}');
  }
}

Map<String, dynamic> _orgData({
  required String name,
  required DateTime createdAt,
  String status = 'active',
  List<String> memberIds = const <String>['u-test'],
}) => <String, dynamic>{
  'name': name,
  'ownerId': 'u-test',
  'memberIds': memberIds,
  'status': status,
  'createdAt': Timestamp.fromDate(createdAt),
};

void main() {
  _RecordingFirebaseFirestore buildFirestore({
    required Map<String, Object?> orgResults,
    required List<String> membershipPaths,
  }) {
    return _RecordingFirebaseFirestore(
      orgCollection: _OrgCollection(orgResults),
      membershipQuery: _MembershipQuery(membershipPaths),
    );
  }

  test(
    'queries collectionGroup members with exact userId and active status filters',
    () async {
      final firestore = buildFirestore(
        membershipPaths: <String>['organizations/org-a/members/u-test'],
        orgResults: <String, Object?>{
          'org-a': _orgData(name: 'Acme', createdAt: DateTime.utc(2026, 1, 2)),
        },
      );
      final repository = FirestoreOrganizationRepository(firestore: firestore);

      final organizations = await repository
          .watchUserOrganizations('u-test')
          .first;

      expect(firestore.collectionGroupCall, 'members');
      expect(firestore.membershipQuery.whereCalls, hasLength(2));

      expect(firestore.membershipQuery.whereCalls[0].field, 'userId');
      expect(
        firestore.membershipQuery.whereCalls[0].named[#isEqualTo],
        'u-test',
      );

      expect(firestore.membershipQuery.whereCalls[1].field, 'status');
      expect(
        firestore.membershipQuery.whereCalls[1].named[#isEqualTo],
        'active',
      );

      // The organizations collection is touched only for single-document
      // gets - direct listing (`where`/`snapshots`) is unimplemented in the
      // fake and would fail this test.
      expect(firestore.collectionCalls, <String>['organizations']);

      expect(organizations, hasLength(1));
      expect(organizations.single.id, 'org-a');
      expect(organizations.single.name, 'Acme');
    },
  );

  test('derives organization ids from membership document paths', () async {
    final firestore = buildFirestore(
      membershipPaths: <String>[
        'organizations/org-a/members/u-test',
        'organizations/org-b/members/u-test',
        'organizations/org-a/members/u-test',
      ],
      orgResults: <String, Object?>{
        'org-a': _orgData(name: 'A', createdAt: DateTime.utc(2026, 1, 1)),
        'org-b': _orgData(name: 'B', createdAt: DateTime.utc(2026, 1, 2)),
      },
    );
    final repository = FirestoreOrganizationRepository(firestore: firestore);

    final organizations = await repository
        .watchUserOrganizations('u-test')
        .first;

    expect(firestore.orgCollection.requestedIds, <String>['org-a', 'org-b']);
    expect(organizations.map((o) => o.id), <String>['org-b', 'org-a']);
  });

  test(
    'excludes denied, missing and inactive organizations from results',
    () async {
      final firestore = buildFirestore(
        membershipPaths: <String>[
          'organizations/org-a/members/u-test',
          'organizations/org-b/members/u-test',
          'organizations/org-c/members/u-test',
          'organizations/org-d/members/u-test',
        ],
        orgResults: <String, Object?>{
          'org-a': _orgData(name: 'A', createdAt: DateTime.utc(2026, 1, 4)),
          'org-b': FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
          'org-c': null,
          'org-d': _orgData(
            name: 'D',
            createdAt: DateTime.utc(2026, 1, 3),
            status: 'suspended',
          ),
        },
      );
      final repository = FirestoreOrganizationRepository(firestore: firestore);

      final organizations = await repository
          .watchUserOrganizations('u-test')
          .first;

      expect(organizations, hasLength(1));
      expect(organizations.single.id, 'org-a');
      // All configured ids were attempted; exclusions happen after the get.
      expect(firestore.orgCollection.requestedIds, hasLength(4));
    },
  );

  test('maps organization fields and sorts by createdAt descending', () async {
    final firestore = buildFirestore(
      membershipPaths: <String>[
        'organizations/org-old/members/u-test',
        'organizations/org-new/members/u-test',
      ],
      orgResults: <String, Object?>{
        'org-old': _orgData(
          name: 'Old Co',
          createdAt: DateTime.utc(2026, 1, 1),
          memberIds: const <String>['u-test', 'u-other'],
        ),
        'org-new': _orgData(
          name: 'New Co',
          createdAt: DateTime.utc(2026, 2, 1),
        ),
      },
    );
    final repository = FirestoreOrganizationRepository(firestore: firestore);

    final organizations = await repository
        .watchUserOrganizations('u-test')
        .first;

    expect(organizations.map((o) => o.id).toList(), <String>[
      'org-new',
      'org-old',
    ]);

    final old = organizations[1];
    expect(old.name, 'Old Co');
    expect(old.status, OrganizationStatus.active);
    expect(old.memberIds, <String>['u-test', 'u-other']);
    expect(old.createdAt.isAtSameMomentAs(DateTime.utc(2026, 1, 1)), isTrue);
  });

  test(
    'surfaces unexpected Firestore errors instead of swallowing them',
    () async {
      final firestore = buildFirestore(
        membershipPaths: <String>['organizations/org-a/members/u-test'],
        orgResults: <String, Object?>{
          'org-a': FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
          ),
        },
      );
      final repository = FirestoreOrganizationRepository(firestore: firestore);

      await expectLater(
        repository.watchUserOrganizations('u-test').first,
        throwsA(isA<FirebaseException>()),
      );
    },
  );

  test(
    'skips memberships with malformed paths without fabricating ids',
    () async {
      final firestore = buildFirestore(
        membershipPaths: <String>[
          'members/u-test',
          'other/u-test/x/y',
          'organizations//members/u-test',
        ],
        orgResults: <String, Object?>{},
      );
      final repository = FirestoreOrganizationRepository(firestore: firestore);

      final organizations = await repository
          .watchUserOrganizations('u-test')
          .first;

      expect(organizations, isEmpty);
      expect(firestore.orgCollection.requestedIds, isEmpty);
    },
  );
}
