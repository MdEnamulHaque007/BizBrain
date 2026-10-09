import 'package:bizbrain/core/widgets/feature_placeholder_view.dart';
import 'package:bizbrain/features/data_sources/presentation/widgets/google_sheets_preview_panel.dart';
import 'package:flutter/material.dart';

/// Data source connection manager: the working Google Sheets preview
/// loader plus labelled placeholders for connectors whose backend does not
/// exist yet.
class DataSourcesScreen extends StatelessWidget {
  const DataSourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              Text(
                'Google Sheets sources',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              GoogleSheetsPreviewPanel(),
              SizedBox(height: 24),
              FeaturePlaceholderView(
                icon: Icons.cable_outlined,
                title: 'Other data sources',
                description:
                    'Connect BizBrain AI to ERPs, databases and REST APIs so '
                    'operational data can flow into analysis. Connections, '
                    'credentials and sync jobs are managed by backend '
                    'services; the client will only show connection status '
                    'and trigger backend-mediated syncs.',
                requirements: <String>[
                  'Credential storage in Google Cloud Secret Manager',
                  'Sync workers on Cloud Run',
                  'Per-tenant connector registry in Firestore',
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
