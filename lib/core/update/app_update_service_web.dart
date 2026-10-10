import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'update_check_logic.dart';

export 'update_check_logic.dart';

/// Web implementation backed by localStorage persistence and a version.txt
/// fetch. The pure version/cooldown decisions live in [UpdateCheckLogic]; this
/// class owns the browser-only plumbing.
class AppUpdateService {
  static final UpdateCheckLogic _logic = UpdateCheckLogic(
    read: (key) async => web.window.localStorage.getItem(key),
    write: (key, value) async {
      try {
        web.window.localStorage.setItem(key, value);
        debugPrint('[UpdateCheck] stored $key = $value');
      } catch (e) {
        debugPrint('[UpdateCheck] failed to store $key: $e');
      }
    },
    fetchLatest: _readLatest,
  );

  static Future<void> initialize() => _logic.initialize();

  static Future<AppUpdateStatus> check() => _logic.check();

  static Future<void> applyUpdate() async {
    final latest = await _readLatest();
    if (latest != null) await _logic.acknowledge(latest);

    final registrations =
        await web.window.navigator.serviceWorker.getRegistrations().toDart;
    for (final registration in registrations.toDart) {
      await registration.unregister().toDart;
    }

    final keys = await web.window.caches.keys().toDart;
    for (final key in keys.toDart) {
      await web.window.caches.delete(key.toDart).toDart;
    }

    web.window.location.reload();
  }

  static Future<String?> _readLatest() async {
    try {
      final response = await web.window
          .fetch('version.txt?t=${DateTime.now().millisecondsSinceEpoch}'.toJS)
          .toDart;
      if (!response.ok) return null;
      final latest = (await response.text().toDart).toDart.trim();
      return latest.isEmpty ? null : latest;
    } catch (_) {
      return null;
    }
  }
}