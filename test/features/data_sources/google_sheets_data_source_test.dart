import 'package:bizbrain/features/data_sources/domain/entities/google_sheets_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GoogleSheetsDataSource.parse spreadsheet id', () {
    test('accepts a raw Spreadsheet ID', () {
      const id = '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms';
      final source = GoogleSheetsDataSource.parse(input: id);

      expect(source.spreadsheetId, id);
      expect(source.sheetName, isNull);
      expect(source.dataRange, isNull);
      expect(source.headerRow, 1);
    });

    test('accepts a full Google Sheets URL', () {
      final source = GoogleSheetsDataSource.parse(
        input:
            'https://docs.google.com/spreadsheets/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/edit?gid=0#gid=0',
      );

      expect(
        source.spreadsheetId,
        '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms',
      );
    });

    test('accepts a pasted URL without a scheme', () {
      final source = GoogleSheetsDataSource.parse(
        input:
            'docs.google.com/spreadsheets/d/1AbCdEfGhIjKlMnOpQrStUvWxYz12/edit',
      );

      expect(source.spreadsheetId, '1AbCdEfGhIjKlMnOpQrStUvWxYz12');
    });

    test('rejects an empty input', () {
      expect(
        () => GoogleSheetsDataSource.parse(input: '   '),
        throwsA(
          isA<GoogleSheetsInputException>().having(
            (e) => e.message,
            'message',
            contains('Enter a Google Sheets URL'),
          ),
        ),
      );
    });

    test('rejects a non-Google URL', () {
      expect(
        () => GoogleSheetsDataSource.parse(
          input: 'https://example.com/spreadsheets/d/abcdef1234/edit',
        ),
        throwsA(isA<GoogleSheetsInputException>()),
      );
    });

    test('rejects garbage input', () {
      expect(
        () => GoogleSheetsDataSource.parse(input: 'not a url !!'),
        throwsA(isA<GoogleSheetsInputException>()),
      );
    });

    test('rejects a URL without a spreadsheet id segment', () {
      expect(
        () => GoogleSheetsDataSource.parse(
          input: 'https://docs.google.com/spreadsheets/u/0/',
        ),
        throwsA(isA<GoogleSheetsInputException>()),
      );
    });
  });

  group('GoogleSheetsDataSource.parse options', () {
    test('trims sheet name, validates range and header row', () {
      final source = GoogleSheetsDataSource.parse(
        input: '1AbCdEfGhIjKlMnOpQrStUvWxYz12',
        sheetName: '  Sales  ',
        dataRange: ' A1:Z1000 ',
        headerRow: 3,
      );

      expect(source.sheetName, 'Sales');
      expect(source.dataRange, 'A1:Z1000');
      expect(source.headerRow, 3);
    });

    test('blank sheet name and range become null', () {
      final source = GoogleSheetsDataSource.parse(
        input: '1AbCdEfGhIjKlMnOpQrStUvWxYz12',
        sheetName: '  ',
        dataRange: '',
      );

      expect(source.sheetName, isNull);
      expect(source.dataRange, isNull);
    });

    test('rejects a header row below 1', () {
      expect(
        () => GoogleSheetsDataSource.parse(
          input: '1AbCdEfGhIjKlMnOpQrStUvWxYz12',
          headerRow: 0,
        ),
        throwsA(
          isA<GoogleSheetsInputException>().having(
            (e) => e.message,
            'message',
            contains('Header row'),
          ),
        ),
      );
    });

    test('rejects an invalid data range', () {
      expect(
        () => GoogleSheetsDataSource.parse(
          input: '1AbCdEfGhIjKlMnOpQrStUvWxYz12',
          dataRange: 'not-a-range',
        ),
        throwsA(
          isA<GoogleSheetsInputException>().having(
            (e) => e.message,
            'message',
            contains('Invalid data range'),
          ),
        ),
      );
    });

    test('rejects a range whose end precedes its start', () {
      expect(
        () => GoogleSheetsDataSource.parse(
          input: '1AbCdEfGhIjKlMnOpQrStUvWxYz12',
          dataRange: 'Z1000:A1',
        ),
        throwsA(isA<GoogleSheetsInputException>()),
      );
    });
  });

  group('A1Range', () {
    test('parses columns and rows 1-based', () {
      final range = A1Range.parse('B2:AA30');

      expect(range.startColumn, 2);
      expect(range.startRow, 2);
      expect(range.endColumn, 27); // AA
      expect(range.endRow, 30);
    });

    test('parses a single cell', () {
      final range = A1Range.parse('C5');

      expect(range.startColumn, 3);
      expect(range.startRow, 5);
      expect(range.endColumn, 3);
      expect(range.endRow, 5);
    });

    test('clips slices to the grid', () {
      final range = A1Range.parse('B2:C3');
      final grid = <List<String>>[
        <String>['h1', 'h2', 'h3'],
        <String>['a', 'b', 'c'],
        <String>['d', 'e', 'f'],
        <String>['g', 'h', 'i'],
      ];

      expect(range.apply(grid), <List<String>>[
        <String>['b', 'c'],
        <String>['e', 'f'],
      ]);
    });

    test('returns an empty slice when everything is out of bounds', () {
      final range = A1Range.parse('A50:A60');
      final grid = <List<String>>[
        <String>['h1'],
        <String>['a'],
      ];

      expect(range.apply(grid), isEmpty);
    });
  });
}
