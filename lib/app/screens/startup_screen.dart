import 'package:bizbrain/core/config/app_config.dart';
import 'package:bizbrain/core/config/app_providers.dart';
import 'package:bizbrain/core/config/firebase_initialization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Startup / configuration screen available at the `/startup` route.
///
/// It reports what the current build can actually do - most importantly
/// whether Firebase is configured - instead of presenting a dashboard that
/// cannot work. Until the navigation shell lands this is also the only place
/// where the environment and Firebase status are shown together.
class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appConfig = ref.watch(appConfigProvider);
    final firebase = ref.watch(firebaseInitializationProvider);

    return _StartupStatusView(appConfig: appConfig, firebase: firebase);
  }
}

class _StartupStatusView extends StatelessWidget {
  const _StartupStatusView({required this.appConfig, required this.firebase});

  final AppConfig appConfig;
  final FirebaseInitialization firebase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(appConfig.appName, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text(
                    '${appConfig.environment.name.toUpperCase()} '
                    '· build ${appConfig.buildLabel}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _statusIcon,
                                size: 22,
                                color: _statusColor(colors),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _statusLabel,
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            firebase.summary,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          if (firebase.missingKeys.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Missing definitions',
                              style: theme.textTheme.labelMedium,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final key in firebase.missingKeys)
                                  Chip(label: Text(key)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _capabilityNote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _statusLabel => switch (firebase.status) {
    FirebaseInitStatus.configured => 'Firebase configured',
    FirebaseInitStatus.notConfigured => 'Firebase not configured',
    FirebaseInitStatus.failed => 'Firebase failed to start',
  };

  IconData get _statusIcon => switch (firebase.status) {
    FirebaseInitStatus.configured => Icons.check_circle_outline,
    FirebaseInitStatus.notConfigured => Icons.cloud_off_outlined,
    FirebaseInitStatus.failed => Icons.error_outline,
  };

  Color _statusColor(ColorScheme colors) => switch (firebase.status) {
    FirebaseInitStatus.configured => colors.primary,
    FirebaseInitStatus.notConfigured => colors.tertiary,
    FirebaseInitStatus.failed => colors.error,
  };

  String get _capabilityNote => switch (firebase.status) {
    FirebaseInitStatus.configured =>
      'Authentication and data services are available.',
    FirebaseInitStatus.notConfigured =>
      'Authentication and data features are disabled for this build. '
          'Provide the missing FIREBASE_* definitions and rebuild to enable '
          'them.',
    FirebaseInitStatus.failed =>
      'Authentication and data features are unavailable until the '
          'initialization problem is resolved.',
  };
}
