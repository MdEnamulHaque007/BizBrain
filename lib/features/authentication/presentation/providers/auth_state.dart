import 'package:bizbrain/features/authentication/domain/entities/app_user.dart';

/// Coarse authentication status used by routing guards and screens.
enum AuthStatus {
  /// The auth stream has not produced its first value yet.
  loading,

  /// A user session exists.
  authenticated,

  /// A local guest demo session: no backend, no [AuthState.user].
  guest,

  /// No session exists and the backend is reachable.
  unauthenticated,

  /// No authentication backend is available for this build.
  unavailable,
}

/// Complete authentication state: status plus transient UI information.
class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.busy = false,
    this.message,
  });

  const AuthState.loading() : this(status: AuthStatus.loading);

  const AuthState.signedOut({String? message})
    : this(status: AuthStatus.unauthenticated, message: message);

  const AuthState.authenticated(AppUser user)
    : this(status: AuthStatus.authenticated, user: user);

  /// Local guest demo session: never carries a user, so every user-scoped
  /// data provider falls back to its empty state.
  const AuthState.guest() : this(status: AuthStatus.guest);

  const AuthState.unavailable(String reason)
    : this(status: AuthStatus.unavailable, message: reason);

  final AuthStatus status;
  final AppUser? user;

  /// True while an auth action (sign-in, registration, ...) is in flight.
  final bool busy;

  /// Latest error/info message, cleared on the next attempt.
  final String? message;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isGuest => status == AuthStatus.guest;
  bool get isUnavailable => status == AuthStatus.unavailable;

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    bool? busy,
    String? message,
    bool clearMessage = false,
    bool clearUser = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      busy: busy ?? this.busy,
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  @override
  String toString() => 'AuthState($status, busy: $busy)';
}
