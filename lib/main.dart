import 'package:bizbrain/app/app.dart';
import 'package:bizbrain/app/bootstrap/app_bootstrap.dart';
import 'package:bizbrain/core/config/app_providers.dart';
import 'package:bizbrain/core/config/firebase_initialization.dart';
import 'package:bizbrain/core/logging/app_logger.dart';
import 'package:bizbrain/core/update/app_update_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  final initialization = await _bootstrap();
  await AppUpdateService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        firebaseInitializationProvider.overrideWith((ref) => initialization),
      ],
      child: const BizBrainApp(),
    ),
  );
}

/// Runs the bootstrap and guarantees a [FirebaseInitialization] is always
/// produced. The bootstrap already reports failures as a state; this is the
/// last line of defence so the UI can still start if anything escapes it.
Future<FirebaseInitialization> _bootstrap() async {
  try {
    return await AppBootstrap.initialize();
  } catch (error, stackTrace) {
    AppLogger.error(
      'Application bootstrap failed',
      error: error,
      stackTrace: stackTrace,
    );
    return const FirebaseInitialization.failed(
      reason: 'The application could not start.',
    );
  }
}
