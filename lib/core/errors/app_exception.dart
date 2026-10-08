/// Application level exceptions.
///
/// Every failure that reaches presentation code should be one of these types
/// (or be mapped to one by `ErrorMapper`) so users always receive a message
/// that is safe and useful to show.
sealed class AppException implements Exception {
  const AppException(this.message);

  /// Message safe to display to an end user.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Authentication failures (sign-in, registration, password reset, ...).
final class AuthException extends AppException {
  const AuthException(super.message, {this.code});

  /// Optional provider error code, e.g. `invalid-credential`.
  final String? code;
}

/// The signed-in user is not allowed to read or write the requested data.
final class PermissionDeniedException extends AppException {
  const PermissionDeniedException([
    super.message = 'You do not have permission to access this data.',
  ]);
}

/// Connectivity problems.
final class NetworkException extends AppException {
  const NetworkException([
    super.message =
        'Unable to reach the server. Check your connection and try again.',
  ]);
}

/// Backend / Firestore responded with an error.
final class ServerException extends AppException {
  const ServerException([
    super.message =
        'The service returned an unexpected error. Please try again.',
  ]);
}

/// The current build or environment is missing required configuration.
final class ConfigurationException extends AppException {
  const ConfigurationException(super.message);
}

/// Input failed validation before reaching a repository.
final class ValidationException extends AppException {
  const ValidationException(
    super.message, {
    this.fieldErrors = const <String, String>{},
  });

  /// Field name -> message, used to highlight form inputs.
  final Map<String, String> fieldErrors;
}

/// The operation depends on backend services that are not deployed yet.
final class BackendServiceUnavailableException extends AppException {
  const BackendServiceUnavailableException([
    super.message =
        'This action requires backend services that are not enabled yet.',
  ]);
}
