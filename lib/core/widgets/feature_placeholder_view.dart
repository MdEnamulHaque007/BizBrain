import 'package:flutter/material.dart';

/// Clearly labelled placeholder used for feature areas whose backend or data
/// layer does not exist yet.
///
/// It intentionally renders *no* sample numbers or fabricated business data:
/// it states what the feature will do and which phase delivers it.
class FeaturePlaceholderView extends StatelessWidget {
  const FeaturePlaceholderView({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.construction_outlined,
    this.plannedPhase = 'Phase 02+',
    this.requirements = const <String>[],
  });

  final String title;
  final String description;
  final IconData icon;
  final String plannedPhase;

  /// Backend / infrastructure items this feature depends on.
  final List<String> requirements;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 32, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.schedule, size: 16),
                        label: Text('Planned for $plannedPhase'),
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        avatar: const Icon(Icons.block, size: 16),
                        label: const Text('Not implemented yet'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(description, style: theme.textTheme.bodyMedium),
                  if (requirements.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Depends on:', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    ...requirements.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Icon(
                                Icons.fiber_manual_record,
                                size: 8,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
