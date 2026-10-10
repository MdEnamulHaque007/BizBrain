import 'package:bizbrain/features/authentication/domain/entities/app_user.dart';
import 'package:bizbrain/features/authentication/presentation/providers/auth_providers.dart';
import 'package:bizbrain/features/authentication/presentation/providers/auth_state.dart';
import 'package:bizbrain/features/organizations/domain/entities/organization.dart';
import 'package:bizbrain/features/organizations/presentation/providers/organization_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/app_test_helpers.dart';

void main() {
  late ProviderContainer container;

  Organization org(String id, String name) => Organization(
    id: id,
    name: name,
    ownerId: 'u-test',
    memberIds: const <String>['u-test'],
    status: OrganizationStatus.active,
    createdAt: DateTime.utc(2026, 1, 8),
  );

  ProviderContainer buildContainer({
    AppUser? user = testUser,
    List<Organization> organizations = const <Organization>[],
  }) {
    return ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(isConfigured: true, initialUser: user),
        ),
        organizationRepositoryProvider.overrideWithValue(
          FakeOrganizationRepository(organizations: organizations),
        ),
      ],
    );
  }

  Future<void> settle(ProviderContainer container) async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final state = container.read(authControllerProvider);
      if (state.status == AuthStatus.authenticated ||
          state.status == AuthStatus.unauthenticated) {
        break;
      }
    }
  }

  /// Subscribes to [effectiveOrganizationProvider] (a plain [Provider] only
  /// recomputes while it has a listener) and polls until it reports the
  /// expected id, since the organization stream emits asynchronously.
  Future<Organization?> untilEffective(String expectedId) async {
    final subscription = container.listen(
      effectiveOrganizationProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    for (var i = 0; i < 40; i++) {
      final organization = container.read(effectiveOrganizationProvider);
      if (organization?.id == expectedId) return organization;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    return container.read(effectiveOrganizationProvider);
  }

  setUp(() => container = buildContainer());

  tearDown(() => container.dispose());

  test('returns the selected organization when one is active', () async {
    container.dispose();
    container = buildContainer(
      organizations: [org('org-a', 'Alpha'), org('org-b', 'Beta')],
    );
    await settle(container);
    container.read(selectedOrganizationIdProvider.notifier).select('org-b');

    final effective = await untilEffective('org-b');
    expect(effective?.id, 'org-b');
  });

  test('returns the first organization when the list is not empty', () async {
    container.dispose();
    container = buildContainer(
      organizations: [org('org-a', 'Alpha'), org('org-b', 'Beta')],
    );
    await settle(container);

    final effective = await untilEffective('org-a');
    expect(effective?.id, 'org-a');
    expect(effective?.name, 'Alpha');
  });

  test('returns a personal fallback when no organizations exist', () async {
    await settle(container);

    final effective = await untilEffective('personal-u-test');
    expect(effective, isNotNull);
    expect(effective?.name, 'Personal');
    expect(effective?.ownerId, 'u-test');
  });

  test('returns null when no user is signed in', () async {
    container.dispose();
    container = buildContainer(user: null);
    await settle(container);

    expect(container.read(effectiveOrganizationProvider), isNull);
  });
}