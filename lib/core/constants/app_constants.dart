/// Shared, environment independent application constants.
abstract final class AppConstants {
  /// Minimum length enforced for new passwords (Firebase minimum).
  static const int minPasswordLength = 8;

  /// Firebase rejects addresses longer than this.
  static const int maxEmailLength = 254;

  static const int maxDisplayNameLength = 60;

  static const int maxOrganizationNameLength = 120;

  static const int maxSearchTermLength = 80;

  /// Application identity used across the shell, notifications and docs.
  static const String appName = 'BizBrain AI';
}
