import 'package:bizbrain/features/organizations/domain/entities/organization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore representation of [Organization].
///
/// `fromMap` is strict: malformed or partially typed documents throw
/// [FormatException] instead of being silently coerced, so a corrupted tenant
/// document is never rendered as if it were valid business data.
class OrganizationModel extends Organization {
  const OrganizationModel({
    required super.id,
    required super.name,
    required super.ownerId,
    required super.memberIds,
    required super.status,
    required super.createdAt,
  });

  factory OrganizationModel.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    final name = map['name'];
    if (name is! String || name.trim().isEmpty) {
      throw FormatException('Organization "$id" is missing a valid "name".');
    }

    final ownerId = map['ownerId'];
    if (ownerId is! String || ownerId.isEmpty) {
      throw FormatException('Organization "$id" is missing a valid "ownerId".');
    }

    final rawMemberIds = map['memberIds'];
    if (rawMemberIds is! List) {
      throw FormatException('Organization "$id" is missing "memberIds".');
    }
    final memberIds = <String>[];
    for (final entry in rawMemberIds) {
      if (entry is! String || entry.isEmpty) {
        throw FormatException(
          'Organization "$id" contains an invalid member id.',
        );
      }
      memberIds.add(entry);
    }
    if (memberIds.isEmpty) {
      throw FormatException('Organization "$id" has no members.');
    }

    final rawStatus = map['status'];
    if (rawStatus is! String) {
      throw FormatException('Organization "$id" is missing "status".');
    }

    final createdAt = _parseDateTime(
      map['createdAt'],
      field: 'createdAt',
      documentId: id,
    );

    return OrganizationModel(
      id: id,
      name: name.trim(),
      ownerId: ownerId,
      memberIds: List<String>.unmodifiable(memberIds),
      status: parseStatus(rawStatus),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'name': name,
    'ownerId': ownerId,
    'memberIds': memberIds,
    'status': status.name,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  static OrganizationStatus parseStatus(String raw) {
    for (final value in OrganizationStatus.values) {
      if (value.name == raw) return value;
    }
    throw FormatException('Unsupported organization status "$raw".');
  }

  static DateTime _parseDateTime(
    Object? value, {
    required String field,
    required String documentId,
  }) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw FormatException(
      'Organization "$documentId" has an invalid "$field".',
    );
  }
}
