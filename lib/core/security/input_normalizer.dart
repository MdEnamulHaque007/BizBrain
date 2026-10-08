/// Normalisation applied to user supplied text before it is validated,
/// stored or sent to a backend.
///
/// This is the only place where raw user input is shaped, so every feature
/// applies identical rules.
abstract final class InputNormalizer {
  /// Lower-cased, trimmed email address.
  static String email(String raw) => raw.trim().toLowerCase();

  /// Collapses repeated whitespace and trims a display name.
  static String displayName(String raw) =>
      raw.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// Single-line text with control characters removed and a length cap.
  static String singleLine(String raw, {int maxLength = 200}) {
    final cleaned = raw
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.length <= maxLength
        ? cleaned
        : cleaned.substring(0, maxLength);
  }
}
