import 'package:bizbrain/core/widgets/feature_placeholder_view.dart';
import 'package:flutter/material.dart';

/// Placeholder for scheduled and on-demand reports.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderView(
      icon: Icons.assessment_outlined,
      title: 'Reports',
      description:
          'Generated and scheduled business reports built from connected data '
          'sources and insights. Report rendering will run on the backend so '
          'exports can be produced without the app being open.',
      requirements: <String>[
        'Report templates and rendering service',
        'Export storage with per-tenant access control',
      ],
    );
  }
}
