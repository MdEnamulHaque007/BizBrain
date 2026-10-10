import 'package:web/web.dart' as web;

/// Persists the active organization id so it survives page reloads.
void persistActiveOrg(String organizationId) {
  try {
    web.window.localStorage.setItem('bizbrain_active_org_id', organizationId);
  } catch (_) {
    // localStorage can be unavailable (private mode / storage disabled).
  }
}