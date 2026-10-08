import 'package:bizbrain/core/widgets/feature_placeholder_view.dart';
import 'package:flutter/material.dart';

/// Placeholder for the activity log module (Phase 02+).
///
/// Renders no fabricated entries: the audit trail is backend-generated.
class ActivityLogsScreen extends StatelessWidget {
  const ActivityLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderView(
      icon: Icons.history_outlined,
      title: 'Activity logs',
      description:
          'Chronological record of sign-ins, data-source syncs, rule '
          'executions and report exports. The audit trail is produced by the '
          'backend and is never fabricated client-side.',
      requirements: <String>[
        'Event ingestion pipeline (Cloud Functions)',
        'Firestore activity collection with retention policy',
        'Organization-scoped, permission-filtered queries',
      ],
    );
  }
}
