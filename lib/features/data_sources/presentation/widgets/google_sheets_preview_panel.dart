import 'dart:async';

import 'package:bizbrain/core/logging/app_logger.dart';
import 'package:bizbrain/features/authentication/presentation/providers/auth_providers.dart';
import 'package:bizbrain/features/data_sources/data/google_sheets/google_sheets_loader.dart';
import 'package:bizbrain/features/data_sources/data/google_sheets/sheet_table.dart';
import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';
import 'package:bizbrain/features/data_sources/domain/entities/google_sheets_data_source.dart';
import 'package:bizbrain/features/data_sources/presentation/providers/data_source_sync_providers.dart';
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
  final TextEditingController _sourceLabelController = TextEditingController();
  final TextEditingController _sheetNameController = TextEditingController();
  final TextEditingController _rangeController = TextEditingController();
  final TextEditingController _headerRowController = TextEditingController(
    text: '1',
  );
  final FocusNode _urlFocusNode = FocusNode();
  final GlobalKey _urlFieldKey = GlobalKey();

  SheetTable? _table;
  SheetCacheModel? _cacheModel;
  String? _editingSourceId;
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
    _sourceLabelController.dispose();
    _sheetNameController.dispose();
    _rangeController.dispose();
    _headerRowController.dispose();
    _urlFocusNode.dispose();
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
      final organizationId = ref.read(effectiveOrganizationProvider)?.id;
      if (organizationId == null || organizationId.isEmpty) {
        setState(() {
          _error = 'Select an organization before connecting a Google Sheet.';
          _table = null;
          _cacheModel = null;
        });
        return;
      }

      final repo = ref.read(cachedDataSourceRepositoryProvider);

      final loaded = await repo.loadDataSource(
        source: source,
        sourceId: sourceId,
        organizationId: organizationId,
        sourceLabel: _sourceLabelController.text.trim().isEmpty
            ? null
            : _sourceLabelController.text.trim(),
        sourceInput: _spreadsheetController.text.trim(),
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
        _editingSourceId = loaded.sourceId;
        _error = null;
      });
      ref.invalidate(sourcesListProvider(organizationId));
      final uid = _signedInUid;
      if (uid != null) {
        // Fire and forget: the cloud must never block the preview.
        unawaited(ref.read(dataSourceSyncProvider).push(loaded, uid: uid));
      }
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

  /// Id of the signed-in user, or null for guest/unauthenticated sessions.
  String? get _signedInUid => ref.read(authControllerProvider).user?.uid;

  Future<void> _restoreLatestCachedSource() async {
    try {
      if (!ref.read(sheetCacheStorageReadyProvider)) {
        return;
      }
      final organizationId = ref.read(effectiveOrganizationProvider)?.id ?? '';
      // Without an organization context (guest mode) the cache must not be
      // read: it may hold a previous tenant's data.
      if (organizationId.isEmpty) return;
      final sources =
          await ref.read(sourcesListProvider(organizationId).future);
      if (!mounted || _userInteracted || sources.isEmpty) return;
      _displayCachedSource(sources.first, editing: false);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to load cached Google Sheets sources',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _displayCachedSource(SheetCacheModel cache, {bool editing = true}) {
    _userInteracted = true;
    final sourceParts = cache.sourceId.split('|');
    final legacyHasSettings = sourceParts.length >= 4;
    final range =
        cache.dataRange ?? (legacyHasSettings ? sourceParts[2] : null);
    final headerRow = cache.headerRow != 1
        ? cache.headerRow
        : legacyHasSettings
        ? int.tryParse(sourceParts[3].replaceFirst(RegExp(r'^h'), '')) ?? 1
        : 1;
    _spreadsheetController.text = cache.sourceInput ?? sourceParts.first;
    _sourceLabelController.text = cache.sourceLabel ?? '';
    _sheetNameController.text = cache.sheetName ?? '';
    _rangeController.text = range ?? '';
    _headerRowController.text = '$headerRow';

    final table = SheetTable(
      headers: cache.columns,
      rows: cache.rows
          .map((record) => cachedRowToList(record, cache.columns))
          .toList(growable: false),
      metadata: SheetSourceMetadata(
        spreadsheetId: sourceParts.first,
        sheetName: cache.sheetName,
        requestedRange: range,
        sourceUrl: cache.sheetUrl,
        loadedAt: cache.fetchedAt,
      ),
    );
    setState(() {
      _table = table;
      _cacheModel = cache;
      _editingSourceId = editing ? cache.sourceId : null;
      _error = null;
    });
  }

  void _clearForm({bool focusUrl = true}) {
    setState(() {
      _sourceLabelController.clear();
      _spreadsheetController.clear();
      _sheetNameController.clear();
      _rangeController.clear();
      _headerRowController.text = '1';
      _table = null;
      _cacheModel = null;
      _editingSourceId = null;
      _error = null;
    });
    if (!focusUrl) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final fieldContext = _urlFieldKey.currentContext;
      if (fieldContext != null) {
        await Scrollable.ensureVisible(
          fieldContext,
          duration: const Duration(milliseconds: 250),
          alignment: 0.2,
        );
      }
      if (mounted) _urlFocusNode.requestFocus();
    });
  }

  Future<void> _refreshCachedSource(SheetCacheModel cache) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final source = GoogleSheetsDataSource.parse(
        input: cache.sourceInput ?? cache.sourceId.split('|').first,
        sheetName: cache.sheetName,
        dataRange:
            cache.dataRange ??
            (cache.sourceId.split('|').length >= 4
                ? cache.sourceId.split('|')[2]
                : null),
        headerRow: cache.headerRow != 1
            ? cache.headerRow
            : cache.sourceId.split('|').length >= 4
            ? int.tryParse(
                    cache.sourceId
                        .split('|')[3]
                        .replaceFirst(RegExp(r'^h'), ''),
                  ) ??
                  1
            : 1,
      );
      final refreshed = await ref
          .read(cachedDataSourceRepositoryProvider)
          .refreshDataSource(
            source: source,
            sourceId: cache.sourceId,
            organizationId: cache.organizationId,
            sourceLabel: cache.sourceLabel,
            sourceInput: cache.sourceInput ?? source.spreadsheetId,
          );
      if (!mounted) return;
      _displayCachedSource(refreshed);
      ref.invalidate(sourcesListProvider(cache.organizationId));
      final uid = _signedInUid;
      if (uid != null) {
        unawaited(ref.read(dataSourceSyncProvider).push(refreshed, uid: uid));
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to refresh Google Sheets source ${cache.sourceId}',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) setState(() => _error = 'Failed to refresh source: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteCachedSource(SheetCacheModel cache) async {
    try {
      await ref.read(sheetCacheManagerProvider).deleteSource(cache.sourceId);
      final uid = _signedInUid;
      if (uid != null) {
        unawaited(ref.read(dataSourceSyncProvider).delete(cache.sourceId, uid: uid));
      }
      if (!mounted) return;
      if (_cacheModel?.sourceId == cache.sourceId) {
        setState(() {
          _cacheModel = null;
          _table = null;
          _sourceLabelController.clear();
          _spreadsheetController.clear();
          _sheetNameController.clear();
          _rangeController.clear();
          _headerRowController.text = '1';
          _editingSourceId = null;
        });
      }
      ref.invalidate(sourcesListProvider(cache.organizationId));
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to delete Google Sheets source ${cache.sourceId}',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) setState(() => _error = 'Failed to delete source: $error');
    }
  }

  /// Pulls the signed-in user's sources from the cloud into the local cache,
  /// then re-displays the current one (or the newest) from the refreshed
  /// cache.
  Future<void> _syncFromCloud() async {
    final uid = _signedInUid;
    final organizationId = ref.read(effectiveOrganizationProvider)?.id;
    if (uid == null || organizationId == null || organizationId.isEmpty) {
      setState(() => _error = 'Sign in to sync your data sources with the cloud.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sources = await ref
          .read(dataSourceSyncProvider)
          .pull(uid: uid, organizationId: organizationId);
      ref.invalidate(sourcesListProvider(organizationId));
      if (_cacheModel != null) {
        final refreshed =
            await ref.read(sheetCacheManagerProvider).getCached(_cacheModel!.sourceId);
        if (refreshed != null) _displayCachedSource(refreshed);
      } else {
        final cachedSources =
            await ref.read(sourcesListProvider(organizationId).future);
        if (cachedSources.isNotEmpty) {
          _displayCachedSource(cachedSources.first, editing: false);
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sources.isEmpty
                ? 'Cloud sync complete. No saved sources found for this account.'
                : 'Cloud sync complete. Restored ${sources.length} source(s).',
          ),
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Cloud sync failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) setState(() => _error = 'Cloud sync failed: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showSourceActions(SheetCacheModel source) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Refresh source'),
              onTap: () => Navigator.pop(context, 'refresh'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete source'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'refresh') {
      await _refreshCachedSource(source);
    } else if (action == 'delete') {
      await _deleteCachedSource(source);
    }
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
    final organizationId = ref.watch(effectiveOrganizationProvider)?.id ?? '';
    final cachedSources = cacheReady && organizationId.isNotEmpty
        ? ref.watch(sourcesListProvider(organizationId))
        : null;

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
              'Enter a publicly shared Google Sheets URL and settings, then '
              'click Connect. No Google credentials are stored in the app.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _sourceLabelController,
              decoration: const InputDecoration(
                labelText: 'Source name (optional)',
                hintText: 'e.g. Footwear inventory',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Saved Google Sheets (${cachedSources?.value?.length ?? 0})',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: _loading ? null : _syncFromCloud,
                  icon: const Icon(Icons.cloud_sync_outlined),
                  label: const Text('Sync cloud'),
                ),
                TextButton.icon(
                  onPressed: _loading ? null : () => _clearForm(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Sheet'),
                ),
              ],
            ),
            if (cachedSources == null)
              Text(
                'Select an organization to view cached sheets.',
                style: theme.textTheme.bodySmall,
              )
            else
              cachedSources.when(
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
                        Card(
                          color: _editingSourceId == source.sourceId
                              ? theme.colorScheme.primaryContainer
                              : null,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              color: _editingSourceId == source.sourceId
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.table_chart_outlined),
                            title: Text(
                              source.sourceLabel ??
                                  source.sheetName ??
                                  source.sourceId,
                            ),
                            subtitle: Text(
                              '${source.sheetName ?? 'Google Sheet'} · '
                              '${source.rowCount} rows'
                              '${source.dataRange == null ? '' : ' · ${source.dataRange}'} · '
                              'Fetched ${source.fetchedAt.toLocal()}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_editingSourceId == source.sourceId)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Chip(
                                      label: const Text('Editing'),
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor:
                                          theme.colorScheme.secondaryContainer,
                                    ),
                                  ),
                                PopupMenuButton<String>(
                                  tooltip: 'Source actions',
                                  onSelected: (action) {
                                    if (action == 'refresh') {
                                      _refreshCachedSource(source);
                                    } else if (action == 'delete') {
                                      _deleteCachedSource(source);
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'refresh',
                                      child: Text('Refresh'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            selected: _cacheModel?.sourceId == source.sourceId,
                            onTap: () => _displayCachedSource(source),
                            onLongPress: () => _showSourceActions(source),
                          ),
                        ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 16),
            Text('Add or Edit Google Sheet', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Enter URL and settings, then click Connect.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              key: _urlFieldKey,
              focusNode: _urlFocusNode,
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
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
                OutlinedButton.icon(
                  onPressed: _loading ? null : () => _clearForm(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Clear Form'),
                ),
                if (_editingSourceId != null)
                  TextButton.icon(
                    onPressed: _loading ? null : () => _clearForm(),
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel Edit'),
                  ),
              ],
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
                                  ref.read(effectiveOrganizationProvider)?.id;
                              if (organizationId == null ||
                                  organizationId.isEmpty) {
                                setState(() {
                                  _error =
                                      'Select an organization to refresh this sheet.';
                                });
                                return;
                              }
                              setState(() => _loading = true);
                              try {
                                final fresh = await ref
                                    .read(cachedDataSourceRepositoryProvider)
                                    .refreshDataSource(
                                      source: source,
                                      sourceId: sourceId,
                                      organizationId: organizationId,
                                      sourceLabel:
                                          _sourceLabelController.text
                                              .trim()
                                              .isEmpty
                                          ? null
                                          : _sourceLabelController.text.trim(),
                                      sourceInput: _spreadsheetController.text
                                          .trim(),
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
                                ref.invalidate(
                                  sourcesListProvider(organizationId),
                                );
                                final uid = _signedInUid;
                                if (uid != null) {
                                  unawaited(
                                    ref.read(dataSourceSyncProvider).push(
                                      fresh,
                                      uid: uid,
                                    ),
                                  );
                                }
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
                              final deletedOrg = _cacheModel?.organizationId;
                              setState(() => _loading = true);
                              try {
                                await ref
                                    .read(cachedDataSourceRepositoryProvider)
                                    .deleteDataSource(_cacheModel!.sourceId);
                                final uid = _signedInUid;
                                if (uid != null) {
                                  unawaited(
                                    ref.read(dataSourceSyncProvider).delete(
                                      _cacheModel!.sourceId,
                                      uid: uid,
                                    ),
                                  );
                                }
                                if (!mounted) return;
                                setState(() {
                                  _cacheModel = null;
                                  _table = null;
                                });
                                ref.invalidate(
                                  sourcesListProvider(deletedOrg ?? ''),
                                );
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
    final visibleRows = table.rows.take(rowLimit).toList(growable: false);
    var columnCount = table.headers.length;
    for (final row in visibleRows) {
      if (row.length > columnCount) columnCount = row.length;
    }

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
              for (var i = 0; i < columnCount; i++)
                DataColumn(
                  label: Text(
                    i < table.headers.length
                        ? (table.headers[i].isEmpty ? ' ' : table.headers[i])
                        : 'Column ${i + 1}',
                  ),
                ),
            ],
            rows: [
              for (final row in visibleRows)
                DataRow(
                  cells: [
                    for (var i = 0; i < columnCount; i++)
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
