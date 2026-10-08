import 'package:bizbrain/app/router/app_router.dart';
import 'package:bizbrain/app/theme/app_theme.dart';
import 'package:bizbrain/core/config/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Application root.
///
/// Material 3 with light and dark palettes from [AppTheme], driven by the
/// application configuration providers and routed through GoRouter (see
/// `app_router.dart` and the redirect rules there). There is deliberately no
/// navigation shell yet - protected screens render directly until that step.
class BizBrainApp extends ConsumerWidget {
  const BizBrainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appConfig = ref.watch(appConfigProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: appConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
