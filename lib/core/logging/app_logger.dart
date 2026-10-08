import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

enum AppLogLevel { debug, info, warning, error }

/// Minimal, dependency free logger.
///
/// * Output is limited to debug builds (`kDebugMode`) so release binaries do
///   not leak operational detail.
/// * Callers must never log credentials, tokens, full email addresses or
///   other personal data; log messages are developer-facing only.
abstract final class AppLogger {
  static const String _tag = 'BizBrain';

  static void debug(String message, {Object? error, StackTrace? stackTrace}) {
    _log(AppLogLevel.debug, message, error: error, stackTrace: stackTrace);
  }

  static void info(String message, {Object? error, StackTrace? stackTrace}) {
    _log(AppLogLevel.info, message, error: error, stackTrace: stackTrace);
  }

  static void warning(String message, {Object? error, StackTrace? stackTrace}) {
    _log(AppLogLevel.warning, message, error: error, stackTrace: stackTrace);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    _log(AppLogLevel.error, message, error: error, stackTrace: stackTrace);
  }

  static void _log(
    AppLogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;

    final buffer = StringBuffer('[${level.name}] $message');
    if (error != null) buffer.write(' | error: $error');

    developer.log(
      buffer.toString(),
      name: _tag,
      level: level.index * 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
