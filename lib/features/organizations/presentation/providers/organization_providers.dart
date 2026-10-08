import 'package:bizbrain/core/config/app_providers.dart';
import 'package:bizbrain/features/authentication/presentation/providers/auth_providers.dart';
import 'package:bizbrain/features/authentication/presentation/providers/auth_state.dart';
import 'package:bizbrain/features/organizations/data/repositories/firestore_organization_repository.dart';
import 'package:bizbrain/features/organizations/data/repositories/unconfigured_organization_repository.dart';
import 'package:bizbrain/features/organizations/domain/entities/organization.dart';
import 'package:bizbrain/features/organizations/domain/repositories/organization_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repository selection follows the Firebase initialization state.
///
/// Guest demo sessions never receive a repository that can touch Firestore:
/// the sign-in-free guest mode must not access real tenant data.
final Provider<OrganizationRepository> organizationRepositoryProvider =
    Provider<OrganizationRepository>((Ref ref) {
      final guest = ref.watch(
        authControllerProvider.select(
          (state) => state.status == AuthStatus.guest,
        ),
      );
      if (guest) {
        return const UnconfiguredOrganizationRepository(
          reason: 'Guest demo mode does not load organization data.',
        );
      }
      final initialization = ref.watch(firebaseInitializationProvider);
      if (initialization.isReady) {
        return FirestoreOrganizationRepository();
      }
      return UnconfiguredOrganizationRepository(reason: initialization.summary);
    });

/// Organizations the signed-in user belongs to.
///
/// Emits an empty list while there is no session (including guest mode); the
/// shell only renders this provider behind an authenticated guard.
final StreamProvider<List<Organization>> myOrganizationsProvider =
    StreamProvider<List<Organization>>((Ref ref) {
      final user = ref.watch(
        authControllerProvider.select((state) => state.user),
      );
      if (user == null) return Stream<List<Organization>>.value(const []);
      return ref
          .watch(organizationRepositoryProvider)
          .watchUserOrganizations(user.uid);
    });

/// Id of the organization the user is currently working with.
///
/// Reset automatically when the signed-in user changes. Persistence across
/// restarts is deferred until secure storage is introduced (Phase 02).
class SelectedOrganizationController extends Notifier<String?> {
  @override
  String? build() {
    // Re-selecting is only meaningful for a stable session; a different user
    // must never inherit the previous user's tenant selection.
    ref.watch(authControllerProvider.select((state) => state.user?.uid));
    return null;
  }

  void select(String organizationId) {
    if (state == organizationId) return;
    state = organizationId;
  }

  void clear() => state = null;
}

final NotifierProvider<SelectedOrganizationController, String?>
selectedOrganizationIdProvider =
    NotifierProvider<SelectedOrganizationController, String?>(
      SelectedOrganizationController.new,
    );

/// The organization currently in focus: the selected one when it still
/// belongs to the user's list, otherwise the most recently created one.
final Provider<Organization?> activeOrganizationProvider =
    Provider<Organization?>((Ref ref) {
      final organizations =
          ref.watch(myOrganizationsProvider).value ?? const <Organization>[];
      if (organizations.isEmpty) return null;

      final selectedId = ref.watch(selectedOrganizationIdProvider);
      for (final organization in organizations) {
        if (organization.id == selectedId) return organization;
      }
      return organizations.first;
    });
