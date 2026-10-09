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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.primary.withValues(alpha: 0.035),
            colors.surface,
            colors.tertiary.withValues(alpha: 0.025),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colors.primary, colors.tertiary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.16),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: colors.onPrimary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          Icons.hub_rounded,
                          size: 30,
                          color: colors.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Data Sources',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: colors.onPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Bring your business data together in one workspace.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onPrimary.withValues(alpha: 0.9),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 28,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Google Sheets sources',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Review the spreadsheet data connected to BizBrain.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.table_chart_rounded, color: colors.tertiary),
                  ],
                ),
                const SizedBox(height: 14),
                const GoogleSheetsPreviewPanel(),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 28,
                      decoration: BoxDecoration(
                        color: colors.tertiary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'More integrations',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(Icons.extension_rounded, color: colors.tertiary),
                  ],
                ),
                const SizedBox(height: 14),
                const FeaturePlaceholderView(
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
      ),
    );
  }
}
