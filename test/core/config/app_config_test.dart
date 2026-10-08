import 'package:bizbrain/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppEnvironment.parse', () {
    test('accepts the three supported values', () {
      expect(
        AppEnvironment.parse(
          'development',
          fallback: AppEnvironment.production,
        ),
        AppEnvironment.development,
      );
      expect(
        AppEnvironment.parse('staging', fallback: AppEnvironment.development),
        AppEnvironment.staging,
      );
      expect(
        AppEnvironment.parse(
          'production',
          fallback: AppEnvironment.development,
        ),
        AppEnvironment.production,
      );
    });

    test('is case and whitespace tolerant', () {
      expect(
        AppEnvironment.parse(
          '  Production ',
          fallback: AppEnvironment.development,
        ),
        AppEnvironment.production,
      );
      expect(
        AppEnvironment.parse('STAGING', fallback: AppEnvironment.production),
        AppEnvironment.staging,
      );
    });

    test('falls back for unknown or blank values', () {
      expect(
        AppEnvironment.parse('qa', fallback: AppEnvironment.development),
        AppEnvironment.development,
      );
      expect(
        AppEnvironment.parse('', fallback: AppEnvironment.staging),
        AppEnvironment.staging,
      );
    });
  });

  group('AppConfig.fromEnvironment', () {
    test('resolves the development environment for local builds', () {
      final config = AppConfig.fromEnvironment();

      // Both plain and configured test runs carry (or default to)
      // development/local, so this must hold in every documented run mode.
      expect(config.environment, AppEnvironment.development);
      expect(config.isDevelopment, isTrue);
      expect(config.isProduction, isFalse);
      expect(config.appName, 'BizBrain AI');
      expect(config.buildLabel, isNotEmpty);
    });

    test('toString exposes environment and build only', () {
      final text = AppConfig.fromEnvironment().toString();
      expect(text, contains('environment: AppEnvironment.development'));
      expect(text, contains('build:'));
      expect(text, isNot(contains('FIREBASE')));
      expect(text, isNot(contains('AIza')));
    });
  });
}
