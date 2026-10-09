import 'dart:js_interop';

import 'package:web/web.dart' as web;

class AppUpdateStatus {
  const AppUpdateStatus({required this.updateAvailable, this.version});

  final bool updateAvailable;
  final String? version;
}

class AppUpdateService {
  static String? _loadedVersion;

  static Future<AppUpdateStatus> check() async {
    try {
      final response = await web.window
          .fetch('version.txt?t=${DateTime.now().millisecondsSinceEpoch}'.toJS)
          .toDart;
      if (!response.ok) {
        return const AppUpdateStatus(updateAvailable: false);
      }

      final latest = (await response.text().toDart).toDart.trim();
      if (latest.isEmpty) {
        return const AppUpdateStatus(updateAvailable: false);
      }

      _loadedVersion ??= latest;
      return AppUpdateStatus(
        updateAvailable: latest != _loadedVersion,
        version: latest,
      );
    } catch (_) {
      return const AppUpdateStatus(updateAvailable: false);
    }
  }

  static Future<void> applyUpdate() async {
    final registrations =
        await web.window.navigator.serviceWorker.getRegistrations().toDart;
    for (final registration in registrations.toDart) {
      await registration.unregister().toDart;
    }

    final keys = await web.window.caches.keys().toDart;
    for (final key in keys.toDart) {
      await web.window.caches.delete(key).toDart;
    }

    web.window.location.reload();
  }
}
