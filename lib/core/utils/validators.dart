import 'package:bizbrain/core/constants/app_constants.dart';
import 'package:bizbrain/core/security/input_normalizer.dart';

/// Form validation returning `null` when valid, or a user-facing message.
///
/// All strings are normalised first, so validators and repositories agree on
/// what "valid input" means.
abstract final class Validators {
  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? email(String? value) {
    final normalized = InputNormalizer.email(value ?? '');
    if (normalized.isEmpty) return 'Enter your email address.';
    if (normalized.length > AppConstants.maxEmailLength) {
      return 'Email address is too long.';
    }
    if (!_email.hasMatch(normalized)) return 'Enter a valid email address.';
    return null;
  }

  static String? password(String? value) {
    final raw = value ?? '';
    if (raw.isEmpty) return 'Enter your password.';
    if (raw.length < AppConstants.minPasswordLength) {
      return 'Password must be at least ${AppConstants.minPasswordLength} characters.';
    }
    if (raw.length > 128) return 'Password is too long.';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Confirm your password.';
    if (value != original) return 'Passwords do not match.';
    return null;
  }

  static String? displayName(String? value) {
    final normalized = InputNormalizer.displayName(value ?? '');
    if (normalized.isEmpty) return 'Enter your name.';
    if (normalized.length > AppConstants.maxDisplayNameLength) {
      return 'Name must be at most ${AppConstants.maxDisplayNameLength} characters.';
    }
    return null;
  }

  static String? organizationName(String? value) {
    final normalized = InputNormalizer.singleLine(
      value ?? '',
      maxLength: AppConstants.maxOrganizationNameLength,
    );
    if (normalized.isEmpty) return 'Enter an organization name.';
    return null;
  }
}
