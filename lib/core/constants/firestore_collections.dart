/// Canonical Firestore collection / sub-collection identifiers.
///
/// Keeping them in one place prevents a typo from silently creating a second
/// collection, which in a multi-tenant system would look like data loss.
abstract final class FirestoreCollections {
  static const String users = 'users';
  static const String organizations = 'organizations';
  static const String members = 'members';
  static const String factories = 'factories';
  static const String departments = 'departments';
  static const String dataSources = 'dataSources';
  static const String businessRules = 'businessRules';
  static const String insights = 'insights';
  static const String agentMemory = 'agentMemory';
  static const String activityLogs = 'activityLogs';
}
