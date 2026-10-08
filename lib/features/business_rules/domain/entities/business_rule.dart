/// A natural-language business rule stored per organization.
///
/// Phase 01 only defines the shape of the contract; parsing, validation and
/// execution happen on backend services where they can be audited.
class BusinessRule {
  const BusinessRule({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.expression,
    required this.enabled,
    required this.createdAt,
  });

  final String id;
  final String organizationId;
  final String title;

  /// Rule written in controlled natural language, e.g.
  /// "Alert me when daily output drops more than 10% below the weekly average".
  final String expression;

  final bool enabled;
  final DateTime createdAt;

  @override
  String toString() => 'BusinessRule($id, enabled: $enabled)';
}
