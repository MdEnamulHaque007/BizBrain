/// Minimal RFC 4180-style CSV parser for Google Sheets exports.
///
/// Supports quoted fields, `""` escapes, embedded commas/newlines and
/// CRLF/LF line endings. Deliberately small: no external dependency is
/// needed for preview-sized data.
List<List<String>> parseCsv(String input) {
  if (input.trim().isEmpty) return const <List<String>>[];

  final rows = <List<String>>[];
  final row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  var fieldWasQuoted = false;

  void endField() {
    row.add(field.toString());
    field.clear();
    fieldWasQuoted = false;
  }

  void endRow() {
    endField();
    rows.add(List<String>.unmodifiable(row));
    row.clear();
  }

  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (inQuotes) {
      if (char == '"') {
        if (i + 1 < input.length && input[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(char);
      }
      continue;
    }
    if (char == '"' && field.isEmpty && !fieldWasQuoted) {
      inQuotes = true;
      fieldWasQuoted = true;
      continue;
    }
    if (char == ',') {
      endField();
      continue;
    }
    if (char == '\r') {
      if (i + 1 < input.length && input[i + 1] == '\n') i++;
      endRow();
      continue;
    }
    if (char == '\n') {
      endRow();
      continue;
    }
    field.write(char);
  }
  // Flush the last field/row unless the input ended with a line break.
  if (field.isNotEmpty || fieldWasQuoted || row.isNotEmpty) {
    endRow();
  }
  return rows;
}
