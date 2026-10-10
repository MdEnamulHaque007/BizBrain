import 'dart:convert';

import 'package:bizbrain/features/data_sources/data/google_sheets/sheet_csv.dart';
import 'package:bizbrain/features/data_sources/data/google_sheets/sheet_table.dart';
import 'package:bizbrain/features/data_sources/domain/entities/google_sheets_data_source.dart';
import 'package:http/http.dart' as http;

/// Machine-readable cause behind a failed [GoogleSheetsLoader.load].
enum SheetsLoadErrorCode {
  invalidSpreadsheet,
  invalidRange,
  inaccessibleSheet,
  emptyData,
  network,
}

/// User-facing load failure. [toString] is the message shown in the UI.
class SheetsLoadException implements Exception {
  const SheetsLoadException(this.code, this.message);

  final SheetsLoadErrorCode code;
  final String message;

  @override
  String toString() => message;
}

/// Read-only loader for publicly accessible ("Anyone with the link can
/// view") Google Sheets.
///
/// Access method: the keyless GVIZ CSV export endpoint - no API key, OAuth
/// token or service-account credential ever touches the client (Phase 1.1
/// requirement). Private spreadsheets are rejected by Google and surface as
/// [SheetsLoadErrorCode.inaccessibleSheet]; supporting those requires a
/// backend OAuth integration and is intentionally out of scope here.
///
/// The requested A1 range is applied client-side because the keyless
/// endpoint does not accept server-side ranges.
class GoogleSheetsLoader {
  GoogleSheetsLoader({http.Client? client, DateTime Function()? clock})
    : _client = client ?? http.Client(),
      _ownsClient = client == null,
      _clock = clock ?? DateTime.now;

  static const String _endpoint =
      'https://docs.google.com/spreadsheets/d/{id}/gviz/tq';

  final http.Client _client;
  final bool _ownsClient;
  final DateTime Function() _clock;

  /// Closes the underlying HTTP client when this loader created it.
  void close() {
    if (_ownsClient) _client.close();
  }

  /// Fetches and structures the spreadsheet described by [source].
  ///
  /// Throws [SheetsLoadException] with a user-facing message for invalid
  /// ranges, inaccessible sheets and empty data; unexpected transport
  /// failures are wrapped as [SheetsLoadErrorCode.network].
  Future<SheetTable> load(GoogleSheetsDataSource source) async {
    A1Range? range;
    if (source.dataRange != null) {
      try {
        range = A1Range.parse(source.dataRange!);
      } on GoogleSheetsInputException catch (error) {
        throw SheetsLoadException(
          SheetsLoadErrorCode.invalidRange,
          error.message,
        );
      }
    }

    final uri = Uri.parse(_endpoint.replaceFirst('{id}', source.spreadsheetId))
        .replace(
          queryParameters: <String, String>{
            'tqx': 'out:csv',
            if (source.sheetName != null) 'sheet': source.sheetName!,
          },
        );

    http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: const <String, String>{'Accept': 'text/csv'},
      );
    } on Exception catch (error) {
      throw SheetsLoadException(
        SheetsLoadErrorCode.network,
        'Could not reach Google Sheets: $error',
      );
    }

    if (response.statusCode != 200) {
      throw SheetsLoadException(
        SheetsLoadErrorCode.inaccessibleSheet,
        'Google Sheets returned HTTP ${response.statusCode}. Check that the '
        'spreadsheet exists and is shared as "Anyone with the link can view".',
      );
    }

    // Decode as UTF-8 explicitly: `response.body` falls back to Latin-1 when
    // the server omits a charset, which corrupts non-ASCII spreadsheet data.
    final csvText = utf8.decode(response.bodyBytes, allowMalformed: true);
    final body = csvText.trim();
    if (body.startsWith('<')) {
      // Google serves an HTML error/login page instead of CSV when the
      // spreadsheet, the sheet name or the sharing settings block access.
      throw SheetsLoadException(
        SheetsLoadErrorCode.inaccessibleSheet,
        'The spreadsheet or sheet is not accessible. Make sure the link is '
        'correct and the spreadsheet is shared as "Anyone with the link can '
        'view", then try again.',
      );
    }
    if (body.isEmpty) {
      throw const SheetsLoadException(
        SheetsLoadErrorCode.emptyData,
        'Google Sheets returned no data.',
      );
    }

    var grid = parseCsv(csvText);
    if (grid.isEmpty) {
      throw const SheetsLoadException(
        SheetsLoadErrorCode.emptyData,
        'The sheet is empty.',
      );
    }

    if (range != null) {
      grid = range.apply(grid);
      if (grid.isEmpty) {
        throw SheetsLoadException(
          SheetsLoadErrorCode.emptyData,
          'The requested range ${source.dataRange} contains no data.',
        );
      }
    }

    final headerIndex = source.headerRow - 1;
    if (headerIndex >= grid.length) {
      throw SheetsLoadException(
        SheetsLoadErrorCode.emptyData,
        'Header row ${source.headerRow} is beyond the available data '
        '(${grid.length} rows).',
      );
    }

    final headers = grid[headerIndex];
    if (headers.every((header) => header.trim().isEmpty)) {
      throw SheetsLoadException(
        SheetsLoadErrorCode.emptyData,
        'Header row ${source.headerRow} contains no column names.',
      );
    }

    final rows = grid
        .sublist(headerIndex + 1)
        .where((row) => row.any((cell) => cell.trim().isNotEmpty))
        .toList(growable: false);
    if (rows.isEmpty) {
      throw const SheetsLoadException(
        SheetsLoadErrorCode.emptyData,
        'The sheet has headers but no data rows.',
      );
    }

    return SheetTable(
      headers: List<String>.unmodifiable(headers),
      rows: rows,
      metadata: SheetSourceMetadata(
        spreadsheetId: source.spreadsheetId,
        sheetName: source.sheetName,
        requestedRange: source.dataRange,
        sourceUrl: uri.toString(),
        loadedAt: _clock(),
      ),
    );
  }
}
