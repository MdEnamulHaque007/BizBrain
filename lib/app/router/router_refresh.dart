import 'package:bizbrain/features/authentication/presentation/providers/auth_providers.dart';
import 'package:bizbrain/features/authentication/presentation/providers/auth_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Makes GoRouter re-evaluate its redirects whenever the session changes.
///
/// The router reads the authentication state with `ref.read` (reading it with
/// `ref.watch` would rebuild the whole [GoRouter] and lose navigation state),
/// so this listenable is what tells it to run the redirect again after a
/// sign-in, sign-out or the first session value arrives.
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref) {
    _subscription = ref.listen(authControllerProvider, (_, _) {
      notifyListeners();
    });
    ref.onDispose(_subscription.close);
  }

  late final ProviderSubscription<AuthState> _subscription;
}
