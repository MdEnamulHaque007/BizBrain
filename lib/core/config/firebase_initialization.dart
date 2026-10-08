/// Outcome of the Firebase bootstrap attempt performed at application start.
///
/// Three distinct states are modelled so the UI can react honestly:
/// * [configured]  - Firebase started and is usable.
/// * [notConfigured] - the build carries no Firebase configuration, a normal
///   state for fresh clones and CI. The app runs, but authentication and
///   Firestore features stay disabled.
/// * [failed] - configuration was present but initialization threw; the
///   reason is kept for diagnostics.
enum FirebaseInitStatus { configured, notConfigured, failed }

class FirebaseInitialization {
  const FirebaseInitialization._(
    this.status, {
    this.reason,
    this.missingKeys = const <String>[],
  });

  const FirebaseInitialization.configured()
    : this._(FirebaseInitStatus.configured);

  const FirebaseInitialization.notConfigured({
    String? reason,
    List<String> missingKeys = const <String>[],
  }) : this._(
         FirebaseInitStatus.notConfigured,
         reason: reason,
         missingKeys: missingKeys,
       );

  const FirebaseInitialization.failed({required String reason})
    : this._(FirebaseInitStatus.failed, reason: reason);

  final FirebaseInitStatus status;

  /// Human readable explanation for [notConfigured] / [failed] states.
  final String? reason;

  /// `--dart-define` keys that were absent for [notConfigured] builds.
  final List<String> missingKeys;

  bool get isReady => status == FirebaseInitStatus.configured;

  /// Short, non-sensitive summary safe to display and log.
  String get summary {
    switch (status) {
      case FirebaseInitStatus.configured:
        return 'Firebase is configured.';
      case FirebaseInitStatus.notConfigured:
        return reason ?? 'Firebase is not configured for this build.';
      case FirebaseInitStatus.failed:
        return reason ?? 'Firebase failed to initialize.';
    }
  }

  @override
  String toString() => 'FirebaseInitialization($status, $summary)';
}
