import 'package:bizbrain/features/data_sources/data/google_sheets/sheet_csv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses simple rows', () {
    expect(parseCsv('a,b\n1,2\n'), <List<String>>[
      <String>['a', 'b'],
      <String>['1', '2'],
    ]);
  });

  test('handles CRLF line endings', () {
    expect(parseCsv('a,b\r\n1,2'), <List<String>>[
      <String>['a', 'b'],
      <String>['1', '2'],
    ]);
  });

  test('keeps commas and newlines inside quotes', () {
    expect(parseCsv('"Smith, John","line1\nline2"'), <List<String>>[
      <String>['Smith, John', 'line1\nline2'],
    ]);
  });

  test('unescapes doubled quotes', () {
    expect(parseCsv('"say ""hi""",x'), <List<String>>[
      <String>['say "hi"', 'x'],
    ]);
  });

  test('preserves empty fields and empty rows', () {
    expect(parseCsv('a,,c\n,,\n1,2,3'), <List<String>>[
      <String>['a', '', 'c'],
      <String>['', '', ''],
      <String>['1', '2', '3'],
    ]);
  });

  test('returns no rows for blank input', () {
    expect(parseCsv(''), isEmpty);
    expect(parseCsv('   \n  '), isEmpty);
  });
}
