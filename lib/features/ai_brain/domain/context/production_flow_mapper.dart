import 'package:bizbrain/features/data_sources/data/google_sheets/sheet_table.dart';

enum ProductionStage { po, cutting, sewing, lasting, fg, export }

class ProductionFlowKey {
  const ProductionFlowKey({
    required this.poNo,
    required this.article,
    required this.color,
  });

  final String poNo;
  final String article;
  final String color;

  String get value => '${_normalize(poNo)}|${_normalize(article)}|${_normalize(color)}';

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

class ProductionFlowRecord {
  ProductionFlowRecord({
    required this.key,
    this.poQuantity = 0,
    this.cuttingQuantity = 0,
    this.sewingQuantity = 0,
    this.lastingQuantity = 0,
    this.fgQuantity = 0,
    this.exportQuantity = 0,
  });

  final ProductionFlowKey key;
  double poQuantity;
  double cuttingQuantity;
  double sewingQuantity;
  double lastingQuantity;
  double fgQuantity;
  double exportQuantity;
}

class ProductionFlowMapper {
  static const _poAliases = <String>['po no', 'po number', 'pono', 'po'];
  static const _articleAliases = <String>[
    'article',
    'article no',
    'article number',
    'article code',
  ];
  static const _colorAliases = <String>[
    'color',
    'colour',
    'color code',
    'colour code',
  ];
  static const _quantityAliases = <String>[
    'quantity',
    'qty',
    'order qty',
    'order quantity',
    'pairs',
  ];

  /// Pattern used to detect a Purchase Order sheet from its name.
  static final RegExp _poNamePattern = RegExp(r'(^|\s)p\.?o\.?(\s|$)');

  /// Whether [name] looks like a Purchase Order sheet.
  static bool isPoSheetName(String name) {
    final normalized = name.trim().toLowerCase();
    return _poNamePattern.hasMatch(normalized) ||
        normalized.contains('purchase order');
  }

  List<ProductionFlowRecord> map(
    Map<ProductionStage, SheetTable> tables,
  ) {
    final mapped = <String, ProductionFlowRecord>{};

    for (final entry in tables.entries) {
      for (final row in entry.value.toRecords()) {
        final normalized = <String, String>{
          for (final cell in row.entries) _header(cell.key): cell.value,
        };

        final poNo = _value(normalized, _poAliases);
        final article = _value(normalized, _articleAliases);
        final color = _value(normalized, _colorAliases);
        if (poNo.isEmpty || article.isEmpty || color.isEmpty) continue;

        final key = ProductionFlowKey(
          poNo: poNo,
          article: article,
          color: color,
        );
        final record = mapped.putIfAbsent(
          key.value,
          () => ProductionFlowRecord(key: key),
        );
        final quantity = _number(_value(normalized, _quantityAliases));
        _addQuantity(record, entry.key, quantity);
      }
    }

    return mapped.values.toList(growable: false);
  }

  static void _addQuantity(
    ProductionFlowRecord record,
    ProductionStage stage,
    double quantity,
  ) {
    switch (stage) {
      case ProductionStage.po:
        record.poQuantity += quantity;
      case ProductionStage.cutting:
        record.cuttingQuantity += quantity;
      case ProductionStage.sewing:
        record.sewingQuantity += quantity;
      case ProductionStage.lasting:
        record.lastingQuantity += quantity;
      case ProductionStage.fg:
        record.fgQuantity += quantity;
      case ProductionStage.export:
        record.exportQuantity += quantity;
    }
  }

  static String _header(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  static String _value(Map<String, String> row, List<String> aliases) {
    for (final alias in aliases) {
      final value = row[_header(alias)]?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  static double _number(String value) {
    final cleaned = value.replaceAll(',', '').trim();
    return double.tryParse(cleaned) ?? 0;
  }
}
