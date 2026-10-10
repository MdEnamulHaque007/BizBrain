import 'dart:typed_data';

/// Non-web fallback: no download mechanism available. Callers should copy the
/// content to the clipboard instead.
bool triggerDownload(Uint8List bytes, String filename, String mimeType) => false;