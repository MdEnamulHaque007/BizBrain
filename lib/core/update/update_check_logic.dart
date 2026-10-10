import 'package:flutter/foundation.dart';

/// Outcome of an update check against the deployed version.
class AppUpdateStatus {
  const AppUpdateStatus({required this.updateAvailable, this.version});

  final bool updateAvailable;
  final String? version;
}

/// Browser-independent version check logic.
///
/// Storage access and the remote version fetch are injected, so the
/// store-vs-latest comparison and the 24-hour cooldown are fully unit-testable
/// without a browser.
class UpdateCheckLogic {
  const UpdateCheckLogic({
    required this.read,
    required this.write,
    required this.fetchLatest,
  });

  /// Reads the stored value for a localStorage key.
  final Future<String?> Function(String key) read;

  /// Writes a value to a localStorage key.
  final Future<void> Function(String key, String value) write;

  /// Fetches the latest deployed version (or null when unavailable).
  final Future<String?> Function() fetchLatest;

  static const _versionKey = 'bizbrain_loaded_version';
  static const _checkTimeKey = 'bizbrain_last_update_check';
  static const _cooldownMs = 24 * 60 * 60 * 1000; // 24 hours

  /// First load: store the version and the check time silently, so the
  /// 24-hour cooldown is already active from the first launch and no update
  /// notification is shown on a fresh install.
  Future<void> initialize() async {
    final latest = await fetchLatest();
    if (latest == null) {
      debugPrint('[UpdateCheck] initialize: version fetch failed');
      return;
    }
    final time = DateTime.now().millisecondsSinceEpoch.toString();
    await write(_versionKey, latest);
    await write(_checkTimeKey, time);
    debugPrint('[UpdateCheck] initialize: stored version=$latest, time=$time');
  }

  Future<AppUpdateStatus> check() async {
    final stored = await read(_versionKey);
    final last = await read(_checkTimeKey);
    final shouldCheck = await _shouldCheck();
    debugPrint(
      '[UpdateCheck] check: stored=$stored, last=$last, shouldCheck=$shouldCheck',
    );
    if (!shouldCheck) {
      return const AppUpdateStatus(updateAvailable: false);
    }
    // Mark immediately (before the network fetch) so a crash or timeout still
    // applies the cooldown and prevents a notification loop.
    await _markChecked();

    final latest = await fetchLatest();
    if (latest == null) {
      debugPrint('[UpdateCheck] result: updateAvailable=false (no latest)');
      return const AppUpdateStatus(updateAvailable: false);
    }

    if (stored == null) {
      await write(_versionKey, latest);
      debugPrint('[UpdateCheck] result: updateAvailable=false (first run)');
      return const AppUpdateStatus(updateAvailable: false);
    }
    if (stored == latest) {
      debugPrint('[UpdateCheck] result: updateAvailable=false (up to date)');
      return const AppUpdateStatus(updateAvailable: false);
    }
    debugPrint('[UpdateCheck] result: updateAvailable=true (latest=$latest)');
    return AppUpdateStatus(updateAvailable: true, version: latest);
  }

  /// Remember the freshly deployed version so the next check is quiet.
  Future<void> acknowledge(String version) async {
    await write(_versionKey, version);
    await _markChecked();
  }

  Future<bool> _shouldCheck() async {
    final last = await read(_checkTimeKey);
    if (last == null) return true;
    final t = int.tryParse(last);
    if (t == null) return true;
    return DateTime.now().millisecondsSinceEpoch - t > _cooldownMs;
  }

  Future<void> _markChecked() async {
    await write(
      _checkTimeKey,
      DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }
}