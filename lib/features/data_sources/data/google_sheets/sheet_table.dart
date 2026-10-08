/// Provenance of a loaded [SheetTable].
class SheetSourceMetadata {
  const SheetSourceMetadata({
    required this.spreadsheetId,
    required this.sheetName,
    required this.requestedRange,
    required this.sourceUrl,
    required this.loadedAt,
  });

  final String spreadsheetId;

  /// `null` when the caller relied on the spreadsheet's first sheet.
  final String? sheetName;

  /// `null` when the whole sheet was requested.
  final String? requestedRange;

  /// Keyless (API-key-free) endpoint the data was fetched from.
  final String sourceUrl;

  final DateTime loadedAt;

  @override
  String toString() =>
      'SheetSourceMetadata(id: $spreadsheetId, sheet: $sheetName, '
      'range: $requestedRange)';
}

/// Structured result of one Google Sheets load.
///
/// The shape (headers + rectangular-ish row lists + counts + provenance) is
/// deliberately analysis-friendly: a future AI step can consume [toRecords]
/// without knowing anything about Google Sheets or CSV.
class SheetTable {
  const SheetTable({
    required this.headers,
    required this.rows,
    required this.metadata,
  });

  /// Column headers from the configured header row.
  final List<String> headers;

  /// Data rows below the header row (header excluded).
  final List<List<String>> rows;

  final SheetSourceMetadata metadata;

  int get rowCount => rows.length;

  int get columnCount {
    var widest = headers.length;
    for (final row in rows) {
      if (row.length > widest) widest = row.length;
    }
    return widest;
  }

  /// Rows as header-keyed records - the adapter a future AI analysis step
  /// consumes. Short rows are padded with empty strings, extra cells keep
  /// their positional key.
  List<Map<String, String>> toRecords() {
    return rows
        .map((row) {
          final record = <String, String>{};
          for (var i = 0; i < headers.length; i++) {
            record[headers[i]] = i < row.length ? row[i] : '';
          }
          for (var i = headers.length; i < row.length; i++) {
            record['column_${i + 1}'] = row[i];
          }
          return record;
        })
        .toList(growable: false);
  }
}
