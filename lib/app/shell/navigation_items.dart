import 'package:bizbrain/app/router/route_paths.dart';
import 'package:flutter/material.dart';

/// One destination of the authenticated application navigation.
class NavDestination {
  const NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.path,
  });

  /// Accessible label, also used for the app bar title.
  final String label;

  /// Icon shown when the destination is not selected.
  final IconData icon;

  /// Icon shown when the destination is selected.
  final IconData selectedIcon;

  /// Absolute route path this destination navigates to.
  final String path;
}

/// The nine primary destinations of BizBrain AI, in display order.
///
/// Single source of truth for the drawer, both navigation rail layouts and
/// the app bar title, so navigation and routing cannot drift apart.
abstract final class NavigationItems {
  static const List<NavDestination> destinations = <NavDestination>[
    NavDestination(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      path: RoutePaths.dashboard,
    ),
    NavDestination(
      label: 'Organizations',
      icon: Icons.domain_outlined,
      selectedIcon: Icons.domain,
      path: RoutePaths.organizations,
    ),
    NavDestination(
      label: 'Data sources',
      icon: Icons.cable_outlined,
      selectedIcon: Icons.cable,
      path: RoutePaths.dataSources,
    ),
    NavDestination(
      label: 'AI Brain',
      icon: Icons.psychology_outlined,
      selectedIcon: Icons.psychology,
      path: RoutePaths.aiBrain,
    ),
    NavDestination(
      label: 'AI Chat',
      icon: Icons.chat_bubble_outline,
      selectedIcon: Icons.chat_bubble,
      path: RoutePaths.aiChat,
    ),
    NavDestination(
      label: 'Business rules',
      icon: Icons.rule_outlined,
      selectedIcon: Icons.rule,
      path: RoutePaths.businessRules,
    ),
    NavDestination(
      label: 'Insights',
      icon: Icons.lightbulb_outlined,
      selectedIcon: Icons.lightbulb,
      path: RoutePaths.insights,
    ),
    NavDestination(
      label: 'Reports',
      icon: Icons.assessment_outlined,
      selectedIcon: Icons.assessment,
      path: RoutePaths.reports,
    ),
    NavDestination(
      label: 'Activity logs',
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
      path: RoutePaths.activityLogs,
    ),
    NavDestination(
      label: 'Time Lapse',
      icon: Icons.timelapse_outlined,
      selectedIcon: Icons.timelapse_rounded,
      path: RoutePaths.timeLapse,
    ),
    NavDestination(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      path: RoutePaths.settings,
    ),
  ];

  /// Index of the destination active for [location], or `-1` when the
  /// location is not one of the registered destinations.
  static int indexOf(String location) => destinations.indexWhere(
    (destination) => destination.path == RoutePaths.normalize(location),
  );

  /// Label of the destination active for [location], or `null`.
  static String? labelOf(String location) {
    final index = indexOf(location);
    if (index < 0) return null;
    return destinations[index].label;
  }
}
