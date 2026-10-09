import 'package:bizbrain/app/shell/navigation_items.dart';
import 'package:bizbrain/core/constants/app_constants.dart';
import 'package:bizbrain/core/utils/responsive.dart';
import 'package:bizbrain/features/authentication/domain/entities/app_user.dart';
import 'package:bizbrain/features/authentication/presentation/providers/auth_providers.dart';
import 'package:bizbrain/features/authentication/presentation/providers/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Width of the extended navigation rail on expanded layouts.
const double _expandedRailWidth = 256;

/// Width of the icon-only navigation rail on medium layouts.
const double _compactRailWidth = 80;

/// Responsive shell wrapping every authenticated route.
///
/// The [location] comes from the `ShellRoute` builder and drives both the
/// active destination and the app bar title, so navigation chrome always
/// matches the URL. Layout follows [AppBreakpoints]:
///
/// * compact (< 640): [NavigationDrawer] behind an app bar menu button,
/// * medium (< 1000): icon-only [NavigationRail],
/// * expanded (>= 1000): extended [NavigationRail] with labels.
///
/// The rail menu column is intentionally *not* wrapped in a scroll view:
/// [NavigationRail] only lays out correctly under bounded height constraints
/// (an unbounded rail trips a framework semantics assertion in debug mode).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.location, required this.child});

  /// Current route path (no query) provided by the router.
  final String location;

  /// The routed page for the current location.
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final compact = AppBreakpoints.isCompact(context);
    final expanded = AppBreakpoints.isExpanded(context);
    final user = ref.watch(
      authControllerProvider.select((state) => state.user),
    );
    final guest = ref.watch(
      authControllerProvider.select(
        (state) => state.status == AuthStatus.guest,
      ),
    );
    final selectedIndex = NavigationItems.indexOf(widget.location);
    final title =
        NavigationItems.labelOf(widget.location) ?? AppConstants.appName;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(title),
        actions: guest ? const <Widget>[_GuestBadge()] : null,
        leading: compact
            ? IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Open navigation',
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              )
            : null,
      ),
      drawer: compact && (user != null || guest)
          ? NavigationDrawer(
              selectedIndex: selectedIndex < 0 ? null : selectedIndex,
              onDestinationSelected: _selectDestination,
              header: user != null
                  ? _AccountHeader(user: user)
                  : const _GuestHeader(),
              footer: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _HelpFooter(onHelp: _showHelp),
                  if (user != null)
                    _LogoutFooter(onLogout: _logout)
                  else
                    _ExitGuestFooter(onExit: _exitGuest),
                ],
              ),
              children: <Widget>[
                for (final destination in NavigationItems.destinations)
                  NavigationDrawerDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: Text(destination.label),
                  ),
              ],
            )
          : null,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!compact) ...<Widget>[
            _RailMenu(
              extended: expanded,
              selectedIndex: selectedIndex,
              user: user,
              guest: guest,
              onSelected: _selectDestination,
              onLogout: _logout,
              onExitGuest: _exitGuest,
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  void _selectDestination(int index) {
    _scaffoldKey.currentState?.closeDrawer();
    context.go(NavigationItems.destinations[index].path);
  }

  void _showHelp() {
    _scaffoldKey.currentState?.closeDrawer();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help'),
        content: const Text(
          'Welcome to BizBrain Help. Help resources will be available here.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Leaves guest mode. The container is captured first: the shell is
  /// disposed as soon as the router redirects back to the sign-in screen.
  void _exitGuest() {
    final container = ProviderScope.containerOf(context, listen: false);
    _scaffoldKey.currentState?.closeDrawer();
    container.read(authControllerProvider.notifier).exitGuest();
  }

  /// Signs the user out and reports a failed attempt with a snack bar.
  ///
  /// The container and messenger are captured before the first `await`: the
  /// shell is disposed as soon as the router redirects to the sign-in screen.
  Future<void> _logout() async {
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    _scaffoldKey.currentState?.closeDrawer();

    await container.read(authControllerProvider.notifier).signOut();

    final state = container.read(authControllerProvider);
    if (state.isAuthenticated && state.message != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(state.message!)));
    }
  }
}

class _HelpFooter extends StatelessWidget {
  const _HelpFooter({required this.onHelp});

  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: ListTile(
        leading: const Icon(Icons.help_outline),
        title: const Text('Help'),
        onTap: onHelp,
      ),
    );
  }
}

/// "Guest Demo" chip in the app bar, visible at every breakpoint while the
/// session is a local guest demo.
class _GuestBadge extends StatelessWidget {
  const _GuestBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Tooltip(
        message: 'Guest demo session: no account, no organization data.',
        child: Chip(
          avatar: Icon(
            Icons.explore_outlined,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          label: const Text('Guest Demo'),
          backgroundColor: theme.colorScheme.secondaryContainer,
          side: BorderSide.none,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

/// Guest summary shown at the top of the navigation drawer.
class _GuestHeader extends StatelessWidget {
  const _GuestHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 20,
            child: Icon(
              Icons.explore_outlined,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Guest Demo', style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'Browsing without an account',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Exit Guest Mode" action pinned to the bottom of the navigation drawer.
class _ExitGuestFooter extends StatelessWidget {
  const _ExitGuestFooter({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: ListTile(
          leading: const Icon(Icons.exit_to_app),
          title: const Text('Exit Guest Mode'),
          onTap: onExit,
        ),
      ),
    );
  }
}

/// Account summary shown at the top of the navigation drawer.
class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: <Widget>[
          _AccountAvatar(user: user, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  user.friendlyName,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Log-out action pinned to the bottom of the navigation drawer.
class _LogoutFooter extends StatelessWidget {
  const _LogoutFooter({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Log out'),
          onTap: onLogout,
        ),
      ),
    );
  }
}

/// The menu column: navigation rail plus the account panel below it.
class _RailMenu extends StatelessWidget {
  const _RailMenu({
    required this.extended,
    required this.selectedIndex,
    required this.user,
    required this.guest,
    required this.onSelected,
    required this.onLogout,
    required this.onExitGuest,
  });

  final bool extended;
  final int selectedIndex;
  final AppUser? user;
  final bool guest;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;
  final VoidCallback onExitGuest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final account = user;
    final railColor =
        theme.navigationRailTheme.backgroundColor ??
        theme.colorScheme.surfaceContainerLow;

    return Container(
      width: extended ? _expandedRailWidth : _compactRailWidth,
      color: railColor,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: NavigationRail(
                extended: extended,
                selectedIndex: selectedIndex < 0 ? null : selectedIndex,
                destinations: <NavigationRailDestination>[
                  for (final destination in NavigationItems.destinations)
                    NavigationRailDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(destination.selectedIcon),
                      label: Text(destination.label),
                    ),
                ],
                onDestinationSelected: onSelected,
              ),
            ),
            const Divider(),
            if (account != null)
              _AccountPanel(
                user: account,
                extended: extended,
                onLogout: onLogout,
              )
            else if (guest)
              _GuestPanel(extended: extended, onExit: onExitGuest),
          ],
        ),
      ),
    );
  }
}

/// Account panel below the rail: avatar + log-out icon when collapsed,
/// avatar, name, e-mail and log-out action when extended.
class _AccountPanel extends StatelessWidget {
  const _AccountPanel({
    required this.user,
    required this.extended,
    required this.onLogout,
  });

  final AppUser user;
  final bool extended;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logOutButton = IconButton(
      icon: const Icon(Icons.logout),
      tooltip: 'Log out',
      onPressed: onLogout,
    );

    if (!extended) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _AccountAvatar(user: user, radius: 16),
            const SizedBox(height: 4),
            logOutButton,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: <Widget>[
          _AccountAvatar(user: user, radius: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  user.friendlyName,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  user.email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          logOutButton,
        ],
      ),
    );
  }
}

/// Guest panel below the rail: demo badge + exit icon when collapsed,
/// badge, description and exit action when extended.
class _GuestPanel extends StatelessWidget {
  const _GuestPanel({required this.extended, required this.onExit});

  final bool extended;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exitButton = IconButton(
      icon: const Icon(Icons.exit_to_app),
      tooltip: 'Exit Guest Mode',
      onPressed: onExit,
    );

    if (!extended) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Tooltip(
              message: 'Guest Demo',
              child: CircleAvatar(
                radius: 16,
                child: Icon(
                  Icons.explore_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            exitButton,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 16,
            child: Icon(
              Icons.explore_outlined,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Guest Demo',
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'No account',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          exitButton,
        ],
      ),
    );
  }
}

/// Circle avatar showing the first letters of the account name, with the
/// full name and e-mail in a tooltip.
class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.user, required this.radius});

  final AppUser user;
  final double radius;

  String get _initials {
    final words = user.friendlyName
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2);
    final letters = words.map((word) => word.substring(0, 1).toUpperCase());
    return letters.isEmpty ? '?' : letters.join();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${user.friendlyName} · ${user.email}',
      child: CircleAvatar(radius: radius, child: Text(_initials)),
    );
  }
}
