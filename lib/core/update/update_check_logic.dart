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

  /// First load: store the version silently, no notification.
  Future<void> initialize() async {
    final latest = await fetchLatest();
    if (latest != null) await write(_versionKey, latest);
  }

  Future<AppUpdateStatus> check() async {
    if (!await _shouldCheck()) {
      return const AppUpdateStatus(updateAvailable: false);
    }
    await _markChecked();

    final latest = await fetchLatest();
    if (latest == null) {
      return const AppUpdateStatus(updateAvailable: false);
    }

    final stored = await read(_versionKey);
    if (stored == null) {
      await write(_versionKey, latest);
      return const AppUpdateStatus(updateAvailable: false);
    }
    if (stored == latest) {
      return const AppUpdateStatus(updateAvailable: false);
    }
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