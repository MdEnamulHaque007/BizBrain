import 'package:bizbrain/core/config/firebase_initialization.dart';
import 'package:bizbrain/core/config/firebase_options.dart';
import 'package:bizbrain/core/logging/app_logger.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Resolves the Firebase options carried by the current build.
typedef FirebaseOptionsResolver = FirebaseOptions? Function();

/// Returns the `--dart-define` keys absent from the current build.
typedef FirebaseMissingKeysReader = List<String> Function();

/// Starts the Firebase SDK. Isolated as a typedef so tests can substitute a
/// fake and never touch a real project.
typedef FirebaseStarter = Future<void> Function(FirebaseOptions options);

/// Application start-up: Flutter binding plus the Firebase bootstrap.
///
/// The bootstrap never throws. Whatever happens it returns a
/// [FirebaseInitialization] describing one of three honest states, so `main()`
/// can render the UI in every case:
///
/// * [FirebaseInitStatus.configured] - configuration present and the SDK
///   accepted it.
/// * [FirebaseInitStatus.notConfigured] - this build carries no Firebase
///   configuration (fresh clone, CI, local work). The application still runs;
///   authentication and data features stay disabled.
/// * [FirebaseInitStatus.failed] - configuration was present but the SDK
///   refused to start. The reason is kept for diagnostics.
///
/// Tests inject [resolveOptions], [readMissingKeys] and [startFirebase] so no
/// live Firebase project is ever required.
abstract final class AppBootstrap {
  static Future<FirebaseInitialization> initialize({
    FirebaseOptionsResolver? resolveOptions,
    FirebaseMissingKeysReader? readMissingKeys,
    FirebaseStarter? startFirebase,
  }) async {
    final resolve = resolveOptions ?? AppFirebaseOptions.resolve;
    final missingKeys = readMissingKeys ?? _buildMissingKeys;
    final start = startFirebase ?? _startFirebase;

    try {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize Hive early so consumers can access it during the session.
      try {
        await Hive.initFlutter();
        if (!Hive.isAdapterRegistered(100)) {
          Hive.registerAdapter(SheetCacheModelAdapter());
        }
        await Hive.openBox<SheetCacheModel>('sheet_cache_v1');
      } catch (e, st) {
        AppLogger.warning(
          'Hive initialization failed',
          error: e,
          stackTrace: st,
        );
      }

      final options = resolve();
      if (options == null) {
        final absent = missingKeys();
        AppLogger.warning(
          absent.isEmpty
              ? 'Firebase is not configured for this build.'
              : 'Firebase is not configured. Missing: ${absent.join(', ')}',
        );
        return FirebaseInitialization.notConfigured(
          reason: 'Firebase configuration is missing for this build.',
          missingKeys: absent,
        );
      }

      await start(options);
      AppLogger.info(
        'Firebase initialized for project "${options.projectId}".',
      );
      return const FirebaseInitialization.configured();
    } catch (error, stackTrace) {
      AppLogger.error(
        'Firebase initialization failed',
        error: error,
        stackTrace: stackTrace,
      );
      return FirebaseInitialization.failed(reason: describeFailure(error));
    }
  }

  /// Short, single line description of [error] for diagnostics. Whitespace is
  /// collapsed and long text truncated so the message stays readable on the
  /// configuration screen.
  static String describeFailure(Object error) {
    final text = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    const limit = 160;
    final detail = text.length <= limit ? text : '${text.substring(0, limit)}…';
    return 'Firebase failed to start. $detail';
  }

  static Future<void> _startFirebase(FirebaseOptions options) {
    return Firebase.initializeApp(options: options);
  }

  static List<String> _buildMissingKeys() => AppFirebaseOptions.missingKeys;
}
