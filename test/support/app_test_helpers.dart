import 'dart:async';

import 'package:bizbrain/app/app.dart';
import 'package:bizbrain/app/router/app_router.dart';
import 'package:bizbrain/core/config/app_providers.dart';
import 'package:bizbrain/core/config/firebase_initialization.dart';
import 'package:bizbrain/core/errors/app_exception.dart';
import 'package:bizbrain/features/authentication/domain/entities/app_user.dart';
import 'package:bizbrain/features/authentication/domain/repositories/auth_repository.dart';
import 'package:bizbrain/features/authentication/presentation/providers/auth_providers.dart';
import 'package:bizbrain/features/organizations/domain/entities/organization.dart';
import 'package:bizbrain/features/organizations/domain/entities/organization_member.dart';
import 'package:bizbrain/features/organizations/domain/repositories/organization_repository.dart';
import 'package:bizbrain/features/organizations/presentation/providers/organization_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Shared test double used across the router and application tests.
const AppUser testUser = AppUser(
  uid: 'u-test',
  email: 'owner@example.com',
  displayName: 'Owner',
);

/// In-memory [AuthRepository]. The initial session is delivered asynchronously
/// (like Firebase Auth) and later changes can be pushed with [emit], or by
/// calling [signOut] / [signIn] through the real auth controller.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    required this.isConfigured,
    this.initialUser,
    this.emitInitial = true,
    this.unavailableReason = 'Authentication backend unavailable in tests.',
  });

  final StreamController<AppUser?> _sessions =
      StreamController<AppUser?>.broadcast();

  @override
  final bool isConfigured;
  final AppUser? initialUser;

  /// When `false` the session never resolves (the controller stays loading).
  final bool emitInitial;

  @override
  final String unavailableReason;

  /// When set, [signOut] throws this instead of clearing the session, so
  /// tests can exercise the failed-logout path.
  Object? signOutError;

  @override
  Stream<AppUser?> authStateChanges() async* {
    if (emitInitial) yield initialUser;
    yield* _sessions.stream;
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    _guard();
    return AppUser(uid: 'u-test', email: email);
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    _guard();
    return AppUser(uid: 'u-test', email: email, displayName: displayName);
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    _guard();
  }

  @override
  Future<void> signOut() async {
    _guard();
    final error = signOutError;
    if (error != null) throw error;
    _sessions.add(null);
  }

  /// Pushes a session change from outside the controller (e.g. a different
  /// sign-in flow or session expiry in another tab).
  void emit(AppUser? user) => _sessions.add(user);

  void _guard() {
    if (!isConfigured) {
      throw ConfigurationException(unavailableReason);
    }
  }
}

/// Read-only in-memory [OrganizationRepository] with no tenants by default.
class FakeOrganizationRepository implements OrganizationRepository {
  const FakeOrganizationRepository({
    this.organizations = const <Organization>[],
  });

  final List<Organization> organizations;

  @override
  Stream<List<Organization>> watchUserOrganizations(String userId) =>
      Stream<List<Organization>>.value(organizations);

  @override
  Future<Organization?> fetchOrganization(String organizationId) async {
    for (final organization in organizations) {
      if (organization.id == organizationId) return organization;
    }
    return null;
  }

  @override
  Stream<OrganizationMember?> watchMembership({
    required String organizationId,
    required String userId,
  }) => const Stream<OrganizationMember?>.empty();
}

/// App plus the provider container, so tests can navigate with the real router
/// and drive the auth controller.
class PumpedApp {
  PumpedApp({required this.container, required this.router});

  final ProviderContainer container;
  final GoRouter router;
}

/// Builds the real application root on top of a fresh [ProviderScope].
///
/// [auth] and [organizations] are injected when the test needs a session or
/// tenant data; when omitted the production configuration-driven repositories
/// are used (which is safe for the "Firebase not configured / failed"
/// scenarios, because those never touch the Firebase SDK).
Future<PumpedApp> pumpApp(
  WidgetTester tester, {
  FirebaseInitialization firebase = const FirebaseInitialization.configured(),
  AuthRepository? auth,
  OrganizationRepository? organizations,
}) async {
  final overrides = [
    firebaseInitializationProvider.overrideWithValue(firebase),
    if (auth != null) authRepositoryProvider.overrideWithValue(auth),
    if (organizations != null)
      organizationRepositoryProvider.overrideWithValue(organizations),
  ];

  await tester.pumpWidget(
    ProviderScope(overrides: overrides, child: const BizBrainApp()),
  );
  await tester.pumpAndSettle();

  final container = ProviderScope.containerOf(
    tester.element(find.byType(BizBrainApp)),
  );
  return PumpedApp(
    container: container,
    router: container.read(appRouterProvider),
  );
}
