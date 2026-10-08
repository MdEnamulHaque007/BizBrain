/// Errors raised while interpreting user-provided Google Sheets input.
///
/// The messages are user-facing and are shown verbatim next to the form.
class GoogleSheetsInputException implements Exception {
  const GoogleSheetsInputException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A validated A1-notation data range such as `A1:Z1000`.
///
/// Rows are 1-based, columns are 1-based (`A == 1`). The range is applied
/// client-side after loading because the keyless CSV endpoint does not accept
/// server-side ranges.
class A1Range {
  const A1Range({
    required this.startColumn,
    required this.startRow,
    required this.endColumn,
    required this.endRow,
  });

  final int startColumn;
  final int startRow;
  final int endColumn;
  final int endRow;

  static final RegExp _pattern = RegExp(
    r'^([A-Za-z]{1,3})([1-9][0-9]*)(?::([A-Za-z]{1,3})([1-9][0-9]*))?$',
  );

  /// Parses `A1:Z1000`, `B2:D20` or a single cell like `A1`.
  ///
  /// Throws [GoogleSheetsInputException] for anything malformed or with the
  /// end before the start.
  static A1Range parse(String raw) {
    final value = raw.trim();
    final match = _pattern.firstMatch(value);
    if (match == null) {
      throw GoogleSheetsInputException(
        'Invalid data range "$raw". Use A1 notation such as A1:Z1000.',
      );
    }
    final startColumn = _columnToIndex(match.group(1)!);
    final startRow = int.parse(match.group(2)!);
    final endColumn = match.group(3) == null
        ? startColumn
        : _columnToIndex(match.group(3)!);
    final endRow = match.group(4) == null
        ? startRow
        : int.parse(match.group(4)!);
    if (endColumn < startColumn || endRow < startRow) {
      throw GoogleSheetsInputException(
        'Invalid data range "$raw": the end of the range must not come '
        'before its start.',
      );
    }
    return A1Range(
      startColumn: startColumn,
      startRow: startRow,
      endColumn: endColumn,
      endRow: endRow,
    );
  }

  /// Converts `A` -> 1, `Z` -> 26, `AA` -> 27 (case-insensitive).
  static int _columnToIndex(String letters) {
    var value = 0;
    for (final code in letters.toUpperCase().codeUnits) {
      value = value * 26 + (code - 0x41) + 1;
    }
    return value;
  }

  /// Slices a full sheet grid down to the requested window.
  ///
  /// Rows/columns outside the grid are clipped; the result may be empty,
  /// which callers treat as "no data in range".
  List<List<String>> apply(List<List<String>> grid) {
    final sliced = <List<String>>[];
    for (var r = startRow - 1; r < endRow && r < grid.length; r++) {
      final row = grid[r];
      final columns = <String>[];
      for (var c = startColumn - 1; c < endColumn && c < row.length; c++) {
        columns.add(row[c]);
      }
      sliced.add(columns);
    }
    return sliced;
  }
}

/// User-provided configuration for one read-only Google Sheets load.
///
/// Parsing happens up front so the UI can report invalid URLs, spreadsheet
/// ids, ranges and header rows before any network request is made.
class GoogleSheetsDataSource {
  const GoogleSheetsDataSource._({
    required this.spreadsheetId,
    required this.sheetName,
    required this.dataRange,
    required this.headerRow,
  });

  /// Validates raw user input: a spreadsheet URL or id, optional sheet name,
  /// optional A1 data range and a 1-based header row number.
  factory GoogleSheetsDataSource.parse({
    required String input,
    String? sheetName,
    String? dataRange,
    int headerRow = 1,
  }) {
    final spreadsheetId = _parseSpreadsheetId(input.trim());
    if (headerRow < 1) {
      throw const GoogleSheetsInputException(
        'Header row must be 1 or greater.',
      );
    }
    final rangeText = dataRange?.trim();
    final range = rangeText == null || rangeText.isEmpty
        ? null
        : A1Range.parse(rangeText);
    final name = sheetName == null || sheetName.trim().isEmpty
        ? null
        : sheetName.trim();

    return GoogleSheetsDataSource._(
      spreadsheetId: spreadsheetId,
      sheetName: name,
      dataRange: range == null ? null : rangeText,
      headerRow: headerRow,
    );
  }

  final String spreadsheetId;
  final String? sheetName;

  /// Original A1 range text (already validated), or `null` for the whole
  /// sheet.
  final String? dataRange;

  /// 1-based row number holding the column headers.
  final int headerRow;

  static final RegExp _rawId = RegExp(r'^[A-Za-z0-9_-]{10,}$');
  static final RegExp _idSegment = RegExp(r'^[A-Za-z0-9_-]+$');

  static String _parseSpreadsheetId(String input) {
    if (input.isEmpty) {
      throw const GoogleSheetsInputException(
        'Enter a Google Sheets URL or Spreadsheet ID.',
      );
    }
    if (_rawId.hasMatch(input)) return input;

    // Pasted links frequently lack a scheme; give them one before parsing.
    var candidate = input;
    if (!candidate.contains('://') && candidate.contains('docs.google.com')) {
      candidate = 'https://$candidate';
    }
    final uri = Uri.tryParse(candidate);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host != 'docs.google.com') {
      throw GoogleSheetsInputException(
        'Invalid Google Sheets link "$input". Paste the spreadsheet URL '
        '(docs.google.com/spreadsheets/...) or the Spreadsheet ID.',
      );
    }
    final segments = uri.pathSegments;
    final dIndex = segments.indexOf('d');
    if (segments.length < 3 ||
        dIndex < 0 ||
        segments[dIndex - 1] != 'spreadsheets' ||
        dIndex + 1 >= segments.length ||
        !_idSegment.hasMatch(segments[dIndex + 1])) {
      throw GoogleSheetsInputException(
        'Invalid Google Sheets link "$input": no Spreadsheet ID found in the '
        'URL.',
      );
    }
    return segments[dIndex + 1];
  }

  @override
  String toString() =>
      'GoogleSheetsDataSource(id: $spreadsheetId, sheet: $sheetName, '
      'range: $dataRange, headerRow: $headerRow)';
}
