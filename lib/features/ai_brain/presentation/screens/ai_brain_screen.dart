import 'package:bizbrain/features/ai_brain/domain/context/production_flow_mapper.dart';
import 'package:bizbrain/features/data_sources/data/google_sheets/sheet_table.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';
import 'package:bizbrain/features/data_sources/presentation/providers/google_sheets_providers.dart';
import 'package:bizbrain/features/organizations/presentation/providers/organization_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiBrainScreen extends ConsumerWidget {
  const AiBrainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organizationId = ref.watch(effectiveOrganizationProvider)?.id ?? '';
    final sources = ref.watch(sourcesListProvider(organizationId));
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Brain'),
        leading: Container(
          margin: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [colors.primary, colors.tertiary]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.psychology_alt_rounded, color: colors.onPrimary),
        ),
      ),
      body: sources.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load cached sheets: $error'),
          ),
        ),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tables = <ProductionStage, SheetTable>{};
    for (final source in sources) {
      final stage = _stageFor(source);
      if (stage == null || tables.containsKey(stage)) continue;
      tables[stage] = _toTable(source);
    }
    final records = ProductionFlowMapper().map(tables);

    if (tables.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: _EmptyState(
            icon: Icons.account_tree_outlined,
            title: 'Your production flow starts here',
            message: 'Connect and cache PO, Cutting, Sewing, Lasting, FG or Export sheets to view mapped analysis.',
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.primary.withValues(alpha: 0.035),
            colors.surface,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary, colors.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.account_tree_rounded, color: colors.onPrimary, size: 30),
                  const SizedBox(height: 12),
                  Text(
                    'Mapped Production Flow',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Follow quantities across your connected production stages.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onPrimary.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _SummaryChip(
                  icon: Icons.hub_rounded,
                  label: '${tables.length} stages detected',
                  color: colors.primary,
                ),
                _SummaryChip(
                  icon: Icons.inventory_2_outlined,
                  label: '${records.length} PO / Article / Color combinations',
                  color: colors.tertiary,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: records.isEmpty
                  ? Center(
                      child: _EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No matching production rows yet',
                        message: 'Sheets were detected, but no rows matched PO No + Article + Color.',
                      ),
                    )
                  : Card(
                      elevation: 0,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: colors.outlineVariant),
                      ),
                      child: SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStatePropertyAll(
                              colors.primaryContainer.withValues(alpha: 0.75),
                            ),
                            headingTextStyle: theme.textTheme.labelLarge?.copyWith(
                              color: colors.onPrimaryContainer,
                              fontWeight: FontWeight.w800,
                            ),
                            dataRowMinHeight: 54,
                            dataRowMaxHeight: 66,
                            columnSpacing: 22,
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
                            rows: records.asMap().entries.map((entry) {
                              final r = entry.value;
                              final tint = entry.key.isEven
                                  ? colors.surface
                                  : colors.surfaceContainerLow;
                              return DataRow(
                                color: WidgetStatePropertyAll(tint),
                                cells: [
                                  DataCell(Text(r.key.poNo)),
                                  DataCell(Text(r.key.article)),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: colors.tertiary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(r.key.color),
                                      ],
                                    ),
                                  ),
                                  DataCell(_QuantityCell(value: _qty(r.poQuantity), color: colors.primary)),
                                  DataCell(_QuantityCell(value: _qty(r.cuttingQuantity), color: colors.secondary)),
                                  DataCell(_QuantityCell(value: _qty(r.sewingQuantity), color: colors.tertiary)),
                                  DataCell(_QuantityCell(value: _qty(r.lastingQuantity), color: colors.primary)),
                                  DataCell(_QuantityCell(value: _qty(r.fgQuantity), color: colors.secondary)),
                                  DataCell(_QuantityCell(value: _qty(r.exportQuantity), color: colors.tertiary)),
                                ],
                              );
                            }).toList(growable: false),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
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
    if (ProductionFlowMapper.isPoSheetName(name)) return ProductionStage.po;
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

  static String _qty(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colors.onSurface)),
        ],
      ),
    );
  }
}

class _QuantityCell extends StatelessWidget {
  const _QuantityCell({required this.value, required this.color});
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(icon, size: 32, color: colors.onPrimaryContainer),
        ),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant, height: 1.45)),
      ],
    );
  }
}
