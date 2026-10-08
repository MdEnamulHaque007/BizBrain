import 'package:bizbrain/core/widgets/feature_placeholder_view.dart';
import 'package:flutter/material.dart';

/// Placeholder for AI insights and the generated news feed.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderView(
      icon: Icons.lightbulb_outlined,
      title: 'Insights & news feed',
      description:
          'A tenant-scoped stream of AI-generated observations, anomaly alerts '
          'and news-feed style updates. Insights are system records written only '
          'by backend services; users can react to them, and feedback is stored '
          'as business memory for future model runs.',
      requirements: <String>[
        'Insight generation pipeline on the backend',
        'organizations/{id}/insights read access with write denied for clients',
        'Feedback memory for ratings and corrections',
      ],
    );
  }
}
