import 'package:bizbrain/core/logging/app_logger.dart';

/// Deployment environment of the BizBrain AI client.
///
/// The value is resolved at build time from the `APP_ENV` dart-define so the
/// same code base can be compiled for development, staging or production
/// without any source changes.
enum AppEnvironment {
  development,
  staging,
  production;

  static AppEnvironment parse(String raw, {required AppEnvironment fallback}) {
    for (final value in AppEnvironment.values) {
      if (value.name == raw.trim().toLowerCase()) return value;
    }
    return fallback;
  }
}

/// Immutable, environment aware application configuration.
///
/// Values are intentionally limited to non-secret build metadata. Firebase
/// connectivity is resolved separately by `AppFirebaseOptions` /
/// `FirebaseInitialization` because those values are supplied per build as
/// well and must never be hardcoded in source control.
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.appName,
    required this.buildLabel,
  });

  /// Reads configuration from `--dart-define` values.
  ///
  /// Supported defines:
  /// * `APP_ENV`     - development (default), staging or production
  /// * `APP_BUILD`   - free form build label shown in the settings screen
  factory AppConfig.fromEnvironment() {
    const rawEnvironment = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    );
    const rawBuild = String.fromEnvironment('APP_BUILD', defaultValue: 'local');

    final environment = AppEnvironment.parse(
      rawEnvironment,
      fallback: AppEnvironment.development,
    );
    if (environment.name != rawEnvironment.trim().toLowerCase()) {
      AppLogger.warning(
        'Unknown APP_ENV "$rawEnvironment", using $environment instead.',
      );
    }

    return AppConfig(
      environment: environment,
      appName: defaultAppName,
      buildLabel: rawBuild,
    );
  }

  static const String defaultAppName = 'BizBrain AI';

  final AppEnvironment environment;
  final String appName;
  final String buildLabel;

  bool get isProduction => environment == AppEnvironment.production;
  bool get isDevelopment => environment == AppEnvironment.development;

  @override
  String toString() =>
      'AppConfig(environment: $environment, build: $buildLabel)';
}
