import 'package:bizbrain/core/errors/app_exception.dart';
import 'package:bizbrain/features/organizations/domain/entities/organization.dart';
import 'package:bizbrain/features/organizations/domain/entities/organization_member.dart';
import 'package:bizbrain/features/organizations/domain/repositories/organization_repository.dart';

/// Used when the build carries no Firebase configuration. Every read fails
/// with an explanatory error - no empty-but-fake organization lists.
class UnconfiguredOrganizationRepository implements OrganizationRepository {
  const UnconfiguredOrganizationRepository({required this.reason});

  final String reason;

  Stream<T> _fail<T>() => Stream<T>.error(ConfigurationException(reason));

  @override
  Stream<List<Organization>> watchUserOrganizations(String userId) =>
      _fail<List<Organization>>();

  @override
  Future<Organization?> fetchOrganization(String organizationId) async {
    throw ConfigurationException(reason);
  }

  @override
  Stream<OrganizationMember?> watchMembership({
    required String organizationId,
    required String userId,
  }) => _fail<OrganizationMember?>();
}
