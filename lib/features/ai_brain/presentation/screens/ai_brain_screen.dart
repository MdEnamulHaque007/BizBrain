import 'package:bizbrain/features/ai_brain/domain/context/production_flow_mapper.dart';
import 'package:bizbrain/features/data_sources/data/google_sheets/sheet_table.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';
import 'package:bizbrain/features/data_sources/presentation/providers/google_sheets_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiBrainScreen extends ConsumerWidget {
  const AiBrainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(sourcesListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('AI Brain')),
      body: sources.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load cached sheets: $error')),
        data: (items) => _MappedProductionFlowView(sources: items),
      ),
    );
  }
}

class _MappedProductionFlowView extends StatelessWidget {
  const _MappedProductionFlowView({required this.sources});
  final List<SheetCacheModel> sources;

  @override
  Widget build(BuildContext context) {
    final tables = <ProductionStage, SheetTable>{};
    for (final source in sources) {
      final stage = _stageFor(source);
      if (stage == null || tables.containsKey(stage)) continue;
      tables[stage] = _toTable(source);
    }
    final records = ProductionFlowMapper().map(tables);

    if (tables.isEmpty) {
      return const Center(
        child: Text('Connect and cache PO, Cutting, Sewing, Lasting, FG or Export sheets to view mapped analysis.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mapped Production Flow', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('${tables.length} stages detected • ${records.length} PO/Article/Color combinations'),
          const SizedBox(height: 16),
          Expanded(
            child: records.isEmpty
                ? const Center(child: Text('Sheets were detected, but no rows matched PO No + Article + Color.'))
                : SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('PO No')),
                          DataColumn(label: Text('Article')),
                          DataColumn(label: Text('Color')),
                          DataColumn(label: Text('PO'), numeric: true),
                          DataColumn(label: Text('Cutting'), numeric: true),
                          DataColumn(label: Text('Sewing'), numeric: true),
                          DataColumn(label: Text('Lasting'), numeric: true),
                          DataColumn(label: Text('FG'), numeric: true),
                          DataColumn(label: Text('Export'), numeric: true),
                        ],
                        rows: records.map((r) => DataRow(cells: [
                          DataCell(Text(r.key.poNo)),
                          DataCell(Text(r.key.article)),
                          DataCell(Text(r.key.color)),
                          DataCell(Text(_qty(r.poQuantity))),
                          DataCell(Text(_qty(r.cuttingQuantity))),
                          DataCell(Text(_qty(r.sewingQuantity))),
                          DataCell(Text(_qty(r.lastingQuantity))),
                          DataCell(Text(_qty(r.fgQuantity))),
                          DataCell(Text(_qty(r.exportQuantity))),
                        ])).toList(growable: false),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  static ProductionStage? _stageFor(SheetCacheModel source) {
    final name = '${source.sourceLabel ?? ''} ${source.sheetName ?? ''}'.toLowerCase();
    if (name.contains('cutting')) return ProductionStage.cutting;
    if (name.contains('sewing')) return ProductionStage.sewing;
    if (name.contains('lasting') || name.contains('production')) return ProductionStage.lasting;
    if (name.contains('finished good') || name.contains('fg')) return ProductionStage.fg;
    if (name.contains('export') || name.contains('shipment')) return ProductionStage.export;
    if (RegExp(r'(^|\\s)p\\.?o\\.?(\\s|$)').hasMatch(name) || name.contains('purchase order')) return ProductionStage.po;
    return null;
  }

  static SheetTable _toTable(SheetCacheModel source) {
    final headers = source.columns;
    final rows = source.rows.map((record) => headers.map((h) => record[h] ?? '').toList()).toList(growable: false);
    return SheetTable(
      headers: headers,
      rows: rows,
      metadata: SheetSourceMetadata(
        spreadsheetId: source.sourceId,
        sheetName: source.sheetName,
        requestedRange: source.dataRange,
        sourceUrl: source.sheetUrl,
        loadedAt: source.fetchedAt,
      ),
    );
  }

  static String _qty(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2);
}
