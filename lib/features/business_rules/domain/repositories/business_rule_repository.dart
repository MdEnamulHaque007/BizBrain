import 'package:bizbrain/features/business_rules/domain/entities/business_rule.dart';

/// Read contract for business rules of one tenant.
abstract interface class BusinessRuleRepository {
  Stream<List<BusinessRule>> watchForOrganization(String organizationId);
}
