import 'dart:convert';

import 'package:bizbrain/features/data_sources/data/google_sheets/google_sheets_loader.dart';
import 'package:bizbrain/features/data_sources/domain/entities/google_sheets_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const validInput = '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms';
  final loadedAt = DateTime.utc(2026, 3, 1, 12);

  const csv =
      'Region,Sales,Quarter\n'
      'North,100,Q1\n'
      'South,200,Q2\n'
      'East,,Q3\n';

  GoogleSheetsLoader loaderWith(MockClient client) =>
      GoogleSheetsLoader(client: client, clock: () => loadedAt);

  GoogleSheetsDataSource source({
    String input = validInput,
    String? sheetName,
    String? dataRange,
    int headerRow = 1,
  }) => GoogleSheetsDataSource.parse(
    input: input,
    sheetName: sheetName,
    dataRange: dataRange,
    headerRow: headerRow,
  );

  test('loads CSV into a SheetTable with metadata and counts', () async {
    late Uri requested;
    final loader = loaderWith(
      MockClient((request) async {
        requested = request.url;
        return http.Response(csv, 200);
      }),
    );

    final table = await loader.load(source(sheetName: 'Sales'));

    expect(requested.host, 'docs.google.com');
    expect(requested.path, contains(validInput));
    expect(requested.path, endsWith('/gviz/tq'));
    expect(requested.queryParameters['tqx'], 'out:csv');
    expect(requested.queryParameters['sheet'], 'Sales');

    expect(table.headers, <String>['Region', 'Sales', 'Quarter']);
    expect(table.rowCount, 3);
    expect(table.columnCount, 3);
    expect(table.rows.first, <String>['North', '100', 'Q1']);

    expect(table.metadata.spreadsheetId, validInput);
    expect(table.metadata.sheetName, 'Sales');
    expect(table.metadata.requestedRange, isNull);
    expect(table.metadata.loadedAt, loadedAt);
    expect(table.metadata.sourceUrl, contains(validInput));

    // AI-friendly record shape.
    expect(table.toRecords().first, <String, String>{
      'Region': 'North',
      'Sales': '100',
      'Quarter': 'Q1',
    });
  });

  test('decodes non-ASCII CSV as UTF-8', () async {
    final loader = loaderWith(
      MockClient(
        (_) async => http.Response.bytes(
          utf8.encode('Name,Qty\nBoot,4\nকাটিং,১২\n'),
          200,
        ),
      ),
    );

    final table = await loader.load(source());

    expect(table.headers, <String>['Name', 'Qty']);
    expect(table.rows, [
      ['Boot', '4'],
      ['কাটিং', '১২'],
    ]);
    expect(table.toRecords().last, <String, String>{
      'Name': 'কাটিং',
      'Qty': '১২',
    });
  });

  test('applies the requested A1 range client-side', () async {
    final loader = loaderWith(MockClient((_) async => http.Response(csv, 200)));

    final table = await loader.load(source(dataRange: 'A1:B3'));

    expect(table.headers, <String>['Region', 'Sales']);
    expect(table.rowCount, 2);
    expect(table.columnCount, 2);
    expect(table.metadata.requestedRange, 'A1:B3');
  });

  test('reports an out-of-bounds range as empty data', () async {
    final loader = loaderWith(MockClient((_) async => http.Response(csv, 200)));

    await expectLater(
      loader.load(source(dataRange: 'A50:B60')),
      throwsA(
        isA<SheetsLoadException>().having(
          (e) => e.code,
          'code',
          SheetsLoadErrorCode.emptyData,
        ),
      ),
    );
  });

  test('reports an HTML response as an inaccessible sheet', () async {
    final loader = loaderWith(
      MockClient(
        (_) async => http.Response('<html><body>Sign in</body></html>', 200),
      ),
    );

    await expectLater(
      loader.load(source()),
      throwsA(
        isA<SheetsLoadException>()
            .having(
              (e) => e.code,
              'code',
              SheetsLoadErrorCode.inaccessibleSheet,
            )
            .having((e) => e.message, 'message', contains('not accessible')),
      ),
    );
  });

  test('reports a non-200 response as an inaccessible sheet', () async {
    final loader = loaderWith(
      MockClient((_) async => http.Response('Not Found', 404)),
    );

    await expectLater(
      loader.load(source()),
      throwsA(
        isA<SheetsLoadException>().having(
          (e) => e.code,
          'code',
          SheetsLoadErrorCode.inaccessibleSheet,
        ),
      ),
    );
  });

  test('reports a blank response as empty data', () async {
    final loader = loaderWith(MockClient((_) async => http.Response('', 200)));

    await expectLater(
      loader.load(source()),
      throwsA(
        isA<SheetsLoadException>().having(
          (e) => e.code,
          'code',
          SheetsLoadErrorCode.emptyData,
        ),
      ),
    );
  });

  test('reports a header-only sheet as empty data', () async {
    final loader = loaderWith(
      MockClient((_) async => http.Response('A,B,C\n', 200)),
    );

    await expectLater(
      loader.load(source()),
      throwsA(
        isA<SheetsLoadException>()
            .having((e) => e.code, 'code', SheetsLoadErrorCode.emptyData)
            .having((e) => e.message, 'message', contains('no data rows')),
      ),
    );
  });

  test('reports a header row beyond the data as empty data', () async {
    final loader = loaderWith(MockClient((_) async => http.Response(csv, 200)));

    await expectLater(
      loader.load(source(headerRow: 10)),
      throwsA(
        isA<SheetsLoadException>().having(
          (e) => e.code,
          'code',
          SheetsLoadErrorCode.emptyData,
        ),
      ),
    );
  });

  test('wraps transport failures as network errors', () async {
    final loader = loaderWith(
      MockClient((_) async => throw http.ClientException('connection reset')),
    );

    await expectLater(
      loader.load(source()),
      throwsA(
        isA<SheetsLoadException>().having(
          (e) => e.code,
          'code',
          SheetsLoadErrorCode.network,
        ),
      ),
    );
  });
}
