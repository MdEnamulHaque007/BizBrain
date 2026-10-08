import 'package:bizbrain/core/logging/app_logger.dart';
import 'package:bizbrain/features/data_sources/data/google_sheets/google_sheets_loader.dart';
import 'package:bizbrain/features/data_sources/data/google_sheets/sheet_table.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';
import 'package:bizbrain/features/data_sources/domain/entities/google_sheets_data_source.dart';
import 'package:bizbrain/features/data_sources/presentation/providers/google_sheets_providers.dart';
import 'package:bizbrain/features/organizations/presentation/providers/organization_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Form + preview table for loading a public Google Sheet (Phase 1.1).
///
/// All input errors (bad URL/id, bad range, bad header row) and load errors
/// (inaccessible sheet, empty data, network) are shown inline below the
/// form; loaded data renders as a basic scrollable preview table.
class GoogleSheetsPreviewPanel extends ConsumerStatefulWidget {
  const GoogleSheetsPreviewPanel({super.key});

  @override
  ConsumerState<GoogleSheetsPreviewPanel> createState() =>
      _GoogleSheetsPreviewPanelState();
}

class _GoogleSheetsPreviewPanelState
    extends ConsumerState<GoogleSheetsPreviewPanel> {
  /// Rows rendered in the preview table; the full row count is always
  /// reported separately.
  static const int _previewRowLimit = 50;

  final TextEditingController _spreadsheetController = TextEditingController();
  final TextEditingController _sheetNameController = TextEditingController();
  final TextEditingController _rangeController = TextEditingController();
  final TextEditingController _headerRowController = TextEditingController(
    text: '1',
  );

  SheetTable? _table;
  SheetCacheModel? _cacheModel;
  String? _error;
  bool _loading = false;
  bool _userInteracted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreLatestCachedSource();
    });
  }

  @override
  void dispose() {
    _spreadsheetController.dispose();
    _sheetNameController.dispose();
    _rangeController.dispose();
    _headerRowController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _userInteracted = true;
    setState(() {
      _loading = true;
      _error = null;
      _cacheModel = null;
    });
    try {
      final headerRowText = _headerRowController.text.trim();
      final headerRow = headerRowText.isEmpty ? 1 : int.tryParse(headerRowText);
      if (headerRow == null) {
        throw const GoogleSheetsInputException(
          'Header row must be a whole number such as 1.',
        );
      }
      final source = GoogleSheetsDataSource.parse(
        input: _spreadsheetController.text,
        sheetName: _sheetNameController.text,
        dataRange: _rangeController.text,
        headerRow: headerRow,
      );

      final sourceId = _sourceId(source);
      final organizationId =
          ref.read(activeOrganizationProvider)?.id ?? 'default';

      final repo = ref.read(cachedDataSourceRepositoryProvider);

      final loaded = await repo.loadDataSource(
        source: source,
        sourceId: sourceId,
        organizationId: organizationId,
      );
      final rows = loaded.rows
          .map((record) => cachedRowToList(record, loaded.columns))
          .toList(growable: false);
      final table = SheetTable(
        headers: loaded.columns,
        rows: rows,
        metadata: SheetSourceMetadata(
          spreadsheetId: source.spreadsheetId,
          sheetName: loaded.sheetName,
          requestedRange: source.dataRange,
          sourceUrl: loaded.sheetUrl,
          loadedAt: loaded.fetchedAt,
        ),
      );
      if (!mounted) return;
      setState(() {
        _table = table;
        _cacheModel = loaded;
        _error = null;
      });
      ref.invalidate(cachedSourcesProvider);
    } on GoogleSheetsInputException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _table = null;
      });
    } on SheetsLoadException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _table = null;
      });
    } catch (error, st) {
      AppLogger.error(
        'Unexpected error loading sheet preview',
        error: error,
        stackTrace: st,
      );
      if (!mounted) return;
      setState(() {
        _error = 'Unexpected error: $error';
        _table = null;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _restoreLatestCachedSource() async {
    try {
      if (!ref.read(sheetCacheStorageReadyProvider)) {
        return;
      }
      final sources = await ref.read(cachedSourcesProvider.future);
      if (!mounted || _userInteracted || sources.isEmpty) return;
      _displayCachedSource(sources.first);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to load cached Google Sheets sources',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _displayCachedSource(SheetCacheModel cache) {
    _userInteracted = true;
    final sourceParts = cache.sourceId.split('|');
    if (sourceParts.length >= 4) {
      _spreadsheetController.text = sourceParts[0];
      _sheetNameController.text = sourceParts[1];
      _rangeController.text = sourceParts[2];
      _headerRowController.text = sourceParts[3].startsWith('h')
          ? sourceParts[3].substring(1)
          : '1';
    } else {
      _spreadsheetController.text = cache.sheetUrl;
      _sheetNameController.text = cache.sheetName ?? '';
      _rangeController.clear();
      _headerRowController.text = '1';
    }

    final table = SheetTable(
      headers: cache.columns,
      rows: cache.rows
          .map((record) => cachedRowToList(record, cache.columns))
          .toList(growable: false),
      metadata: SheetSourceMetadata(
        spreadsheetId: sourceParts.first,
        sheetName: cache.sheetName,
        requestedRange: sourceParts.length >= 4 ? sourceParts[2] : null,
        sourceUrl: cache.sheetUrl,
        loadedAt: cache.fetchedAt,
      ),
    );
    setState(() {
      _table = table;
      _cacheModel = cache;
      _error = null;
    });
  }

  List<String> cachedRowToList(Map<String, String> rec, List<String> headers) {
    final row = <String>[];
    for (final h in headers) {
      row.add(rec[h] ?? '');
    }
    final extraKeys = rec.keys.where((k) => k.startsWith('column_')).toList();
    extraKeys.sort((a, b) {
      final na = int.tryParse(a.split('_').last) ?? 0;
      final nb = int.tryParse(b.split('_').last) ?? 0;
      return na.compareTo(nb);
    });
    for (final k in extraKeys) {
      row.add(rec[k] ?? '');
    }
    return row;
  }

  String _sourceId(GoogleSheetsDataSource source) =>
      '${source.spreadsheetId}|${source.sheetName ?? ''}|${source.dataRange ?? ''}|${source.headerRow}';

  String _cacheStatusText(SheetCacheModel m) {
    final age = DateTime.now().difference(m.fetchedAt);
    if (age < const Duration(minutes: 5)) {
      return 'Fresh • just now';
    }
    if (age < const Duration(hours: 24)) {
      return 'Cached • ${_formatDuration(age)} ago';
    }
    if (ref.read(sheetCacheManagerProvider).isStale(m)) {
      return 'Stale • ${_formatDuration(age)} old';
    }
    return 'Cached • ${_formatDuration(age)} ago';
  }

  String _formatDuration(Duration d) {
    if (d.inDays >= 1) return '${d.inDays}d';
    if (d.inHours >= 1) return '${d.inHours}h';
    if (d.inMinutes >= 1) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final table = _table;
    final cacheReady = ref.watch(sheetCacheStorageReadyProvider);
    final cachedSources = cacheReady ? ref.watch(cachedSourcesProvider) : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.table_chart_outlined,
                  size: 32,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Google Sheets preview',
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Load a publicly shared spreadsheet ("Anyone with the link can '
              'view") for a read-only preview. No Google credentials are '
              'stored in the app.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text('Cached sheets', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            if (!cacheReady)
              Text(
                'Local cache is unavailable. Restart the app to initialize '
                'persistent sheet storage.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              )
            else
              cachedSources!.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text(
                  'Could not load cached sheets: $error',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                data: (sources) {
                  if (sources.isEmpty) {
                    return Text(
                      'No cached sheets yet.',
                      style: theme.textTheme.bodySmall,
                    );
                  }
                  return Column(
                    children: [
                      for (final source in sources)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.table_chart_outlined),
                          title: Text(source.sheetName ?? source.sourceId),
                          subtitle: Text(
                            '${source.rowCount} rows · ${_cacheStatusText(source)}',
                          ),
                          selected: _cacheModel?.sourceId == source.sourceId,
                          onTap: () => _displayCachedSource(source),
                        ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _spreadsheetController,
              decoration: const InputDecoration(
                labelText: 'Spreadsheet URL or ID',
                hintText: 'https://docs.google.com/spreadsheets/d/...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _sheetNameController,
                    decoration: const InputDecoration(
                      labelText: 'Sheet name (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _rangeController,
                    decoration: const InputDecoration(
                      labelText: 'Data range (optional)',
                      hintText: 'A1:Z1000',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _headerRowController,
                    decoration: const InputDecoration(
                      labelText: 'Header row',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loading ? null : _load,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              label: Text(_loading ? 'Connecting…' : 'Connect'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        _error!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (table != null && _error == null) ...[
              const SizedBox(height: 16),
              Text(
                'Sheet ${table.metadata.spreadsheetId}'
                '${table.metadata.sheetName == null ? '' : ' · ${table.metadata.sheetName}'}'
                ' · ${table.rowCount} rows × ${table.columnCount} columns'
                '${table.metadata.requestedRange == null ? '' : ' · range ${table.metadata.requestedRange}'}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              if (_cacheModel != null) ...[
                Row(
                  children: [
                    Icon(
                      _cacheModel != null
                          ? (ref
                                    .read(sheetCacheManagerProvider)
                                    .isStale(_cacheModel!)
                                ? Icons.warning
                                : Icons.check_circle)
                          : Icons.info_outline,
                      size: 16,
                      color: _cacheModel != null
                          ? (ref
                                    .read(sheetCacheManagerProvider)
                                    .isStale(_cacheModel!)
                                ? Colors.amber
                                : Colors.green)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _cacheStatusText(_cacheModel!),
                      style: theme.textTheme.bodySmall,
                    ),
                    const Spacer(),
                    FilledButton.tonalIcon(
                      onPressed: _loading
                          ? null
                          : () async {
                              final source = GoogleSheetsDataSource.parse(
                                input: _spreadsheetController.text,
                                sheetName: _sheetNameController.text,
                                dataRange: _rangeController.text,
                                headerRow:
                                    int.tryParse(_headerRowController.text) ??
                                    1,
                              );
                              final sourceId = _sourceId(source);
                              final organizationId =
                                  ref.read(activeOrganizationProvider)?.id ??
                                  'default';
                              setState(() => _loading = true);
                              try {
                                final fresh = await ref
                                    .read(cachedDataSourceRepositoryProvider)
                                    .refreshDataSource(
                                      source: source,
                                      sourceId: sourceId,
                                      organizationId: organizationId,
                                    );
                                final rows = fresh.rows
                                    .map(
                                      (r) => cachedRowToList(r, fresh.columns),
                                    )
                                    .toList(growable: false);
                                final t = SheetTable(
                                  headers: fresh.columns,
                                  rows: rows,
                                  metadata: SheetSourceMetadata(
                                    spreadsheetId: source.spreadsheetId,
                                    sheetName: fresh.sheetName,
                                    requestedRange: source.dataRange,
                                    sourceUrl: fresh.sheetUrl,
                                    loadedAt: fresh.fetchedAt,
                                  ),
                                );
                                if (!mounted) return;
                                setState(() {
                                  _table = t;
                                  _cacheModel = fresh;
                                  _error = null;
                                });
                                ref.invalidate(cachedSourcesProvider);
                              } catch (e) {
                                if (!mounted) return;
                                setState(() {
                                  _error = 'Failed to refresh: $e';
                                });
                              } finally {
                                if (mounted) setState(() => _loading = false);
                              }
                            },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: _loading
                          ? null
                          : () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete cached copy?'),
                                  content: const Text(
                                    'This will delete the locally cached copy of this sheet.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true) return;
                              setState(() => _loading = true);
                              try {
                                await ref
                                    .read(cachedDataSourceRepositoryProvider)
                                    .deleteDataSource(_cacheModel!.sourceId);
                                if (!mounted) return;
                                setState(() {
                                  _cacheModel = null;
                                  _table = null;
                                });
                                ref.invalidate(cachedSourcesProvider);
                              } catch (e) {
                                if (!mounted) return;
                                setState(() {
                                  _error = 'Failed to delete cache: $e';
                                });
                              } finally {
                                if (mounted) setState(() => _loading = false);
                              }
                            },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete cache'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              _PreviewTable(table: table, rowLimit: _previewRowLimit),
            ],
          ],
        ),
      ),
    );
  }
}

/// Basic horizontally scrollable preview of a [SheetTable].
class _PreviewTable extends StatelessWidget {
  const _PreviewTable({required this.table, required this.rowLimit});

  final SheetTable table;
  final int rowLimit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleRows = table.rows.take(rowLimit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(
              theme.colorScheme.surfaceContainerHighest,
            ),
            columns: [
              for (final header in table.headers)
                DataColumn(label: Text(header.isEmpty ? ' ' : header)),
            ],
            rows: [
              for (final row in visibleRows)
                DataRow(
                  cells: [
                    for (var i = 0; i < table.headers.length; i++)
                      DataCell(Text(i < row.length ? row[i] : '')),
                  ],
                ),
            ],
          ),
        ),
        if (table.rowCount > rowLimit)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Showing the first $rowLimit of ${table.rowCount} rows.',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
