import 'package:bizbrain/core/widgets/feature_placeholder_view.dart';
import 'package:flutter/material.dart';

/// Placeholder for the settings module (Phase 02+).
///
/// Shows the planned scope only; no editable values are invented.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderView(
      icon: Icons.settings_outlined,
      title: 'Settings',
      description:
          'Workspace preferences: organization profile, member roles, '
          'integrations and notification defaults. Changes will be written '
          'through the backend configuration API.',
      requirements: <String>[
        'Organization membership and role model',
        'Firestore-backed settings documents',
        'Audit trail for configuration changes',
      ],
    );
  }
}
