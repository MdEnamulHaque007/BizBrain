import 'package:bizbrain/core/release_history/release_history_service.dart';
import 'package:flutter/material.dart';

/// Displays recent commits and the corresponding GitHub Actions status.
class ReleaseHistoryDialog extends StatefulWidget {
  const ReleaseHistoryDialog({super.key});

  @override
  State<ReleaseHistoryDialog> createState() => _ReleaseHistoryDialogState();
}

class _ReleaseHistoryDialogState extends State<ReleaseHistoryDialog> {
  late Future<ReleaseHistoryResult> _future;
  final ReleaseHistoryService _service = ReleaseHistoryService();

  @override
  void initState() {
    super.initState();
    _future = _service.load();
  }

  void _refresh() {
    setState(() => _future = _service.load());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.history),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('BizBrain — Release History',
                        style: theme.textTheme.titleLarge),
                  ),
                  IconButton(
                    tooltip: 'Refresh history',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Recent GitHub commits and deployment workflow status.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<ReleaseHistoryResult>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Could not load release history: ${snapshot.error}'),
                      );
                    }
                    final result = snapshot.data;
                    if (result == null || result.entries.isEmpty) {
                      return Center(
                        child: Text(result?.message ?? 'No release history found.'),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (result.message != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(result.message!,
                                style: theme.textTheme.bodySmall),
                          ),
                        Expanded(
                          child: ListView.separated(
                            itemCount: result.entries.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final entry = result.entries[index];
                              final date = entry.date == null
                                  ? 'Date unavailable'
                                  : entry.date!.toLocal().toString().substring(0, 16);
                              final statusColor = switch (entry.status) {
                                'Success' => Colors.green,
                                'Failed' => theme.colorScheme.error,
                                'In progress' => Colors.orange,
                                _ => theme.colorScheme.onSurfaceVariant,
                              };
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                                leading: CircleAvatar(
                                  child: Icon(_iconFor(entry.releaseType)),
                                ),
                                title: Text(entry.message),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(date),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${entry.releaseType} • ${entry.sha.length > 7 ? entry.sha.substring(0, 7) : entry.sha}',
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(Icons.circle, size: 9, color: statusColor),
                                          const SizedBox(width: 6),
                                          Flexible(child: Text(entry.status)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: IconButton(
                                  tooltip: 'Show commit ID',
                                  icon: const Icon(Icons.copy),
                                  onPressed: () {
                                    showDialog<void>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Commit ID'),
                                        content: SelectableText(entry.sha),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('Close'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'Feature':
        return Icons.new_releases_outlined;
      case 'Bug Fix':
        return Icons.build_outlined;
      case 'Improvement':
        return Icons.trending_up;
      case 'Documentation':
        return Icons.description_outlined;
      default:
        return Icons.commit;
    }
  }
}
