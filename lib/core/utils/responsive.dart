import 'package:flutter/widgets.dart';

/// Responsive breakpoints for the application shell.
///
/// Three layout tiers are supported:
/// * compact  (< 640)  - phone: navigation drawer, single column content
/// * medium   (< 1000) - tablet / small laptop: icon rail, two column content
/// * expanded (>=1000) - desktop: extended rail, three column content
abstract final class AppBreakpoints {
  static const double compact = 640;
  static const double medium = 1000;

  static Size sizeOf(BuildContext context) => MediaQuery.sizeOf(context);

  static bool isCompact(BuildContext context) =>
      sizeOf(context).width < compact;

  static bool isMedium(BuildContext context) {
    final width = sizeOf(context).width;
    return width >= compact && width < medium;
  }

  static bool isExpanded(BuildContext context) =>
      sizeOf(context).width >= medium;

  /// Number of dashboard cards per grid row for the current window size.
  static int dashboardColumns(BuildContext context) {
    if (isCompact(context)) return 1;
    if (isMedium(context)) return 2;
    return 3;
  }

  /// Maximum readable content width so wide desktop screens stay legible.
  static const double contentMaxWidth = 1280;
}
