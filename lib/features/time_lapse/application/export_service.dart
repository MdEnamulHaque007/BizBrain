import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'export_service_stub.dart'
    if (dart.library.js_interop) 'export_service_web.dart';

/// Export helpers for the Time Lapse report.
///
/// PNP capture renders a [RenderRepaintBoundary] to bytes on every platform;
/// the actual download is platform-specific:
///   - web: Blob + anchor triggered in `export_service_web.dart`
///   - elsewhere: none, so [downloadBytes]/[downloadText] return `false`
///     and the caller falls back (e.g. clipboard copy).
class ExportService {
  ExportService._();

  /// Renders [boundary] (which should wrap the chart) to a PNG and starts a
  /// download on the web. Returns `true` when a download was triggered.
  static Future<bool> capturePng(
    RenderRepaintBoundary boundary,
    String filename,
  ) async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return false;
      return downloadBytes(data.buffer.asUint8List(), filename, 'image/png');
    } finally {
      image.dispose();
    }
  }

  /// Starts a download of UTF-8 [content] on the web.
  static bool downloadText(String content, String filename) {
    return downloadBytes(
      Uint8List.fromList(utf8.encode(content)),
      filename,
      'text/csv;charset=utf-8',
    );
  }

  /// Downloads raw [bytes] via a platform-specific mechanism.
  static bool downloadBytes(Uint8List bytes, String filename, String mimeType) {
    return triggerDownload(bytes, filename, mimeType);
  }
}