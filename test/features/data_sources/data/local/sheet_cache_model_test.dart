import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SheetCacheModel', () {
    test('serializes and deserializes all fields', () {
      final cache = SheetCacheModel(
        sourceId: 'sheet-1',
        organizationId: 'org-1',
        sheetUrl: 'https://docs.google.com/sheets/d/sheet-1',
        sheetName: 'Inventory',
        rows: const [
          {'Name': 'Boot', 'Qty': '12'},
        ],
        columns: const ['Name', 'Qty'],
        fetchedAt: DateTime.utc(2026, 10, 8),
        rowCount: 1,
        version: 1,
        sourceLabel: 'Warehouse inventory',
        sourceInput: 'https://docs.google.com/spreadsheets/d/sheet-1',
        dataRange: 'A1:B20',
        headerRow: 2,
      );

      final restored = SheetCacheModel.fromJson(cache.toJson());

      expect(restored, cache);
      expect(restored.hashCode, cache.hashCode);
      expect(restored.sourceLabel, 'Warehouse inventory');
      expect(restored.dataRange, 'A1:B20');
      expect(restored.headerRow, 2);
    });

    test('copyWith and deep equality handle nested records', () {
      final cache = SheetCacheModel(
        sourceId: 'sheet-1',
        organizationId: 'org-1',
        sheetUrl: 'url',
        sheetName: null,
        rows: const [
          {'Name': 'Boot'},
        ],
        columns: const ['Name'],
        fetchedAt: DateTime.utc(2026),
        rowCount: 1,
        version: 1,
      );

      expect(cache.copyWith(rowCount: 2).rowCount, 2);
      expect(
        cache,
        cache.copyWith(
          rows: const [
            {'Name': 'Boot'},
          ],
        ),
      );
    });
  });
}
