import 'package:bizbrain/features/ai_brain/domain/context/production_flow_mapper.dart';
import 'package:bizbrain/features/data_sources/data/google_sheets/sheet_table.dart';
import 'package:flutter_test/flutter_test.dart';

final _loadedAt = DateTime.utc(2026, 1, 1);

void main() {
  group('ProductionFlowMapper.isPoSheetName', () {
    test('matches real PO sheet names', () {
      expect(ProductionFlowMapper.isPoSheetName('po'), isTrue);
      expect(ProductionFlowMapper.isPoSheetName('PO'), isTrue);
      expect(ProductionFlowMapper.isPoSheetName('po 2026'), isTrue);
      expect(ProductionFlowMapper.isPoSheetName('PO sheet'), isTrue);
      expect(ProductionFlowMapper.isPoSheetName('  po. '), isTrue);
      expect(ProductionFlowMapper.isPoSheetName('P.O'), isTrue);
      expect(ProductionFlowMapper.isPoSheetName('Purchase Order 2026'), isTrue);
    });

    test('rejects unrelated sheet names', () {
      expect(ProductionFlowMapper.isPoSheetName('apple'), isFalse);
      expect(ProductionFlowMapper.isPoSheetName('production'), isFalse);
      expect(ProductionFlowMapper.isPoSheetName('cutting'), isFalse);
      expect(ProductionFlowMapper.isPoSheetName(''), isFalse);
    });
  });

  group('ProductionFlowKey.normalize', () {
    test('collapses whitespace and lowercases the key value', () {
      const key = ProductionFlowKey(
        poNo: '  PO  001 ',
        article: ' Boot',
        color: 'Black ',
      );
      expect(key.value, 'po 001|boot|black');
    });
  });

  group('ProductionFlowMapper.map', () {
    test('merges rows across stages by PO/Article/Color and sums quantities',
        () {
      final po = SheetTable(
        headers: const ['PO No', 'Article', 'Color', 'Qty'],
        rows: const [
          ['PO 001', ' Boot', 'Black', '100'],
          ['PO 001', 'Boot', 'Black', '50'],
        ],
        metadata: SheetSourceMetadata(
          spreadsheetId: 'sheet-a',
          sheetName: 'po',
          requestedRange: null,
          sourceUrl: 'url',
          loadedAt: _loadedAt,
        ),
      );
      final sewing = SheetTable(
        headers: const ['PO NO', 'ARTICLE', 'COLOUR', 'QUANTITY'],
        rows: const [
          [' PO 001', 'Boot', 'Black ', '120'],
        ],
        metadata: SheetSourceMetadata(
          spreadsheetId: 'sheet-b',
          sheetName: 'sewing',
          requestedRange: null,
          sourceUrl: 'url',
          loadedAt: _loadedAt,
        ),
      );

      final records = ProductionFlowMapper().map({
        ProductionStage.po: po,
        ProductionStage.sewing: sewing,
      });

      expect(records, hasLength(1));
      expect(records.single.key.poNo, 'PO 001');
      expect(records.single.key.article, 'Boot');
      expect(records.single.key.color, 'Black');
      // 100 + 50 from PO, 120 from Sewing; whitespace/case differences merge.
      expect(records.single.poQuantity, 150);
      expect(records.single.sewingQuantity, 120);
      expect(records.single.cuttingQuantity, 0);
    });

    test('ignores rows without PO/Article/Color triple', () {
      final table = SheetTable(
        headers: const ['PO No', 'Article', 'Color', 'Qty'],
        rows: const [
          ['PO 001', '', 'Black', '100'],
          ['', 'Boot', 'Black', '50'],
        ],
        metadata: SheetSourceMetadata(
          spreadsheetId: 'sheet-a',
          sheetName: 'po',
          requestedRange: null,
          sourceUrl: 'url',
          loadedAt: _loadedAt,
        ),
      );

      final records = ProductionFlowMapper().map({ProductionStage.po: table});

      expect(records, isEmpty);
    });

    test('parses numbers with thousands separators', () {
      final table = SheetTable(
        headers: const ['PO No', 'Article', 'Color', 'Qty'],
        rows: const [
          ['PO 001', 'Boot', 'Black', '1,250'],
        ],
        metadata: SheetSourceMetadata(
          spreadsheetId: 'sheet-a',
          sheetName: 'po',
          requestedRange: null,
          sourceUrl: 'url',
          loadedAt: _loadedAt,
        ),
      );

      final records = ProductionFlowMapper().map({ProductionStage.po: table});

      expect(records.single.poQuantity, 1250);
    });

    test('matches prefixed quantity headers like PO Qty and PO Quantity', () {
      final table = SheetTable(
        headers: const ['PO No', 'Article', 'Color', 'PO Qty'],
        rows: const [
          ['PO 001', 'Boot', 'Black', '100'],
          ['PO 001', 'Boot', 'Black', '50'],
        ],
        metadata: SheetSourceMetadata(
          spreadsheetId: 'sheet-a',
          sheetName: 'po',
          requestedRange: null,
          sourceUrl: 'url',
          loadedAt: _loadedAt,
        ),
      );
      final table2 = SheetTable(
        headers: const ['PO NO', 'ARTICLE', 'COLOUR', 'PO QUANTITY'],
        rows: const [
          ['PO 002', 'Sandal', 'Brown', '75'],
        ],
        metadata: SheetSourceMetadata(
          spreadsheetId: 'sheet-b',
          sheetName: 'po',
          requestedRange: null,
          sourceUrl: 'url',
          loadedAt: _loadedAt,
        ),
      );

      final records = ProductionFlowMapper().map({
        ProductionStage.po: table,
        ProductionStage.cutting: table2,
      });

      expect(records, hasLength(2));
      final first = records.firstWhere((r) => r.key.poNo == 'PO 001');
      expect(first.poQuantity, 150);
      final second = records.firstWhere((r) => r.key.poNo == 'PO 002');
      expect(second.cuttingQuantity, 75);
    });

    test('reads a Date column into the record', () {
      final table = SheetTable(
        headers: const ['PO No', 'Article', 'Color', 'Qty', 'Date'],
        rows: const [
          ['PO 001', 'Boot', 'Black', '100', '24/05/2026'],
        ],
        metadata: SheetSourceMetadata(
          spreadsheetId: 'sheet-a',
          sheetName: 'po',
          requestedRange: null,
          sourceUrl: 'url',
          loadedAt: _loadedAt,
        ),
      );

      final records = ProductionFlowMapper().map({ProductionStage.po: table});

      expect(records.single.date, '24/05/2026');
    });

    test('keeps date null when no readable date column exists', () {
      final table = SheetTable(
        headers: const ['PO No', 'Article', 'Color', 'Qty'],
        rows: const [
          ['PO 001', 'Boot', 'Black', '100'],
        ],
        metadata: SheetSourceMetadata(
          spreadsheetId: 'sheet-a',
          sheetName: 'po',
          requestedRange: null,
          sourceUrl: 'url',
          loadedAt: _loadedAt,
        ),
      );

      final records = ProductionFlowMapper().map({ProductionStage.po: table});

      expect(records.single.date, isNull);
    });
  });
}