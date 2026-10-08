import 'dart:async';

import 'package:bizbrain/core/config/app_providers.dart';
import 'package:bizbrain/core/errors/app_exception.dart';
import 'package:bizbrain/core/errors/error_mapper.dart';
import 'package:bizbrain/core/logging/app_logger.dart';
import 'package:bizbrain/features/authentication/data/repositories/firebase_auth_repository.dart';
import 'package:bizbrain/features/authentication/data/repositories/unconfigured_auth_repository.dart';
import 'package:bizbrain/features/authentication/domain/entities/app_user.dart';
import 'package:bizbrain/features/authentication/domain/repositories/auth_repository.dart';
import 'package:bizbrain/features/authentication/presentation/providers/auth_state.dart';
import 'package:bizbrain/features/data_sources/presentation/providers/google_sheets_providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// Repository selection is configuration-driven:
/// * Firebase configured -> real Firebase Auth
/// * otherwise -> repository that refuses every operation
final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) {
      final initialization = ref.watch(firebaseInitializationProvider);
      if (initialization.isReady) {
        return FirebaseAuthRepository(FirebaseAuth.instance);
      }
      return UnconfiguredAuthRepository(reason: initialization.summary);
    });

/// Owns the auth session: exposes [AuthState] and the user actions that
/// mutate it. Every action reports failures through `AuthState.message`.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final repository = ref.watch(authRepositoryProvider);

    if (!repository.isConfigured) {
      AppLogger.info(
        'Authentication backend unavailable: ${repository.unavailableReason}',
      );
      return AuthState.unavailable(repository.unavailableReason);
    }

    final subscription = repository.authStateChanges().listen(
      _applySession,
      onError: (Object error) {
        AppLogger.error('Auth stream error', error: error);
        state = state.copyWith(
          busy: false,
          message: ErrorMapper.messageFor(error),
        );
      },
    );
    ref.onDispose(subscription.cancel);

    return const AuthState.loading();
  }

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  void _applySession(AppUser? user) {
    // A guest demo session is purely local; backend session events must not
    // overwrite it.
    if (state.status == AuthStatus.guest) return;
    if (user == null) {
      // Only clear a session when we actually had one; keep action messages.
      state = state.status == AuthStatus.authenticated
          ? const AuthState.signedOut()
          : state.copyWith(status: AuthStatus.unauthenticated, clearUser: true);
    } else {
      state = AuthState.authenticated(user);
    }
  }

  /// Returns `true` when the sign-in succeeded. On failure the state carries
  /// a message for the form to display.
  Future<bool> signIn({required String email, required String password}) async {
    if (!await _guardConfigured()) return false;
    state = state.copyWith(busy: true, clearMessage: true);
    try {
      final user = await _repository.signIn(email: email, password: password);
      state = AuthState.authenticated(user);
      return true;
    } catch (error) {
      return _fail(error);
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (!await _guardConfigured()) return false;
    state = state.copyWith(busy: true, clearMessage: true);
    try {
      final user = await _repository.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      state = AuthState.authenticated(user);
      return true;
    } catch (error) {
      return _fail(error);
    }
  }

  /// Returns `true` when the reset email was handed to the provider.
  Future<bool> sendPasswordReset({required String email}) async {
    if (!await _guardConfigured()) return false;
    state = state.copyWith(busy: true, clearMessage: true);
    try {
      await _repository.sendPasswordReset(email: email);
      state = state.copyWith(busy: false);
      return true;
    } catch (error) {
      return _fail(error);
    }
  }

  Future<void> signOut() async {
    if (!await _guardConfigured()) return;
    state = state.copyWith(busy: true, clearMessage: true);
    try {
      await _repository.signOut();
      try {
        // AppUser has no organization membership field, so clear all local
        // sheet caches to ensure no tenant data survives a user switch.
        if (Hive.isBoxOpen('sheet_cache_v1')) {
          await ref.read(sheetCacheManagerProvider).invalidateAll();
        }
      } catch (error, stackTrace) {
        AppLogger.error(
          'Signed out, but Google Sheets cache cleanup failed',
          error: error,
          stackTrace: stackTrace,
        );
        state = const AuthState.signedOut(
          message: 'Signed out, but local Google Sheets cache cleanup failed.',
        );
        return;
      }
      state = const AuthState.signedOut();
    } catch (error) {
      _fail(error);
    }
  }

  /// Enters a local guest demo session. No repository call: works even when
  /// the auth backend is unconfigured.
  void continueAsGuest() {
    if (state.status == AuthStatus.guest) return;
    state = const AuthState.guest();
  }

  /// Leaves guest mode and returns to the sign-in screen, or to the
  /// unavailable state when no auth backend exists.
  void exitGuest() {
    if (state.status != AuthStatus.guest) return;
    final repository = _repository;
    state = repository.isConfigured
        ? const AuthState.signedOut()
        : AuthState.unavailable(repository.unavailableReason);
  }

  /// Clears the latest message after the user has seen it.
  void clearMessage() {
    if (state.message != null) {
      state = state.copyWith(clearMessage: true);
    }
  }

  Future<bool> _guardConfigured() async {
    final repository = ref.read(authRepositoryProvider);
    if (repository.isConfigured) return true;
    state = AuthState.unavailable(repository.unavailableReason);
    return false;
  }

  bool _fail(Object error) {
    if (error is AppException) {
      AppLogger.warning('Auth action failed: ${error.message}');
    } else {
      AppLogger.error('Unexpected auth failure', error: error);
    }
    state = state.copyWith(busy: false, message: ErrorMapper.messageFor(error));
    return false;
  }
}

final NotifierProvider<AuthController, AuthState> authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
