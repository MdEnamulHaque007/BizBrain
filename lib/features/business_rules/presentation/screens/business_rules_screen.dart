import 'package:bizbrain/core/widgets/feature_placeholder_view.dart';
import 'package:flutter/material.dart';

/// Placeholder for the natural-language business rule editor.
class BusinessRulesScreen extends StatelessWidget {
  const BusinessRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderView(
      icon: Icons.rule_outlined,
      title: 'Business rules',
      description:
          'Define and manage rules in controlled natural language, for example '
          '"alert me when daily output falls more than 10% below the weekly '
          'average". Rules are stored per organization, versioned and executed '
          'by the backend rule engine - never evaluated with write access from '
          'the client.',
      requirements: <String>[
        'Rule parsing and validation service',
        'Versioned rule storage under organizations/{id}/businessRules',
        'Scheduled execution with audit logging',
      ],
    );
  }
}
