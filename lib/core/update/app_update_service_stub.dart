import 'update_check_logic.dart';

export 'update_check_logic.dart';

/// Non-web stub: nothing to check or update outside the browser, but keeps
/// the exact [AppUpdateService] API so every platform compiles.
class AppUpdateService {
  static Future<void> initialize() async {}

  static Future<AppUpdateStatus> check() async =>
      const AppUpdateStatus(updateAvailable: false);

  static Future<void> applyUpdate() async {}
}