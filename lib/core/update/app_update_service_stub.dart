class AppUpdateStatus {
  const AppUpdateStatus({required this.updateAvailable, this.version});

  final bool updateAvailable;
  final String? version;
}

class AppUpdateService {
  static Future<AppUpdateStatus> check() async =>
      const AppUpdateStatus(updateAvailable: false);

  static Future<void> applyUpdate() async {}
}
