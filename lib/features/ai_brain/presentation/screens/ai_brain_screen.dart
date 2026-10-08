import 'package:bizbrain/core/widgets/feature_placeholder_view.dart';
import 'package:flutter/material.dart';

/// Future home of the AI brain. The page documents the planned capability
/// set; no inference happens in the client.
class AiBrainScreen extends StatelessWidget {
  const AiBrainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderView(
      icon: Icons.psychology_outlined,
      title: 'AI Brain',
      description:
          'The AI brain coordinates specialist agents, builds business context '
          'from connected data, executes business rules, retrieves organizational '
          'knowledge and generates insights with human approval checkpoints. '
          'Contracts for every capability already exist under '
          'lib/features/ai_brain/domain; inference itself will run exclusively '
          'on authenticated backend services - never inside the Flutter app.',
      requirements: <String>[
        'Backend model gateway (Cloud Functions / Cloud Run) holding model credentials',
        'External data connectors feeding the business context builder',
        'Business rule engine and knowledge store',
        'Approval workflow with audited decisions',
      ],
    );
  }
}
