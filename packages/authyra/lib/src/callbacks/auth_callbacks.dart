import 'package:authyra/src/callbacks/callback_result.dart';
import 'package:authyra/src/interfaces/auth_sign_in_params.dart';
import 'package:authyra/src/models/auth_user.dart';

/// Middleware hooks executed before each auth action.
///
/// Subclass [AuthCallbacks] and pass an instance to [AuthyraClient] (via
/// [AuthyraClientBuilder.setCallbacks]) to intercept sign-in, sign-out,
/// session creation, account switching, and token refresh.
///
/// Every hook returns a [CallbackResult]. Returning [CallbackResult.deny]
/// **blocks** the corresponding operation and surfaces an
/// [AuthenticationFailedException] to the caller. All hooks have
/// default no-op implementations that return [CallbackResult.allow],
/// so override only the hooks you need.
///
/// ## Implementing a guard
///
/// ```dart
/// class MyAuthCallbacks extends AuthCallbacks {
///   @override
///   Future<CallbackResult> onBeforeSignIn(
///     String providerName,
///     AuthSignInParams? params,
///   ) async {
///     if (await isRateLimited(providerName)) {
///       return const CallbackResult.deny('Too many sign-in attempts');
///     }
///     return const CallbackResult.allow();
///   }
///
///   @override
///   Future<CallbackResult> onBeforeSessionCreate(
///     AuthUser user,
///     String providerName,
///   ) async {
///     final exists = await myDb.users.exists(email: user.email);
///     if (!exists) return const CallbackResult.deny('Account not found');
///     return const CallbackResult.allow();
///   }
/// }
/// ```
///
/// See also:
/// - [CallbackResult], the allow/deny value returned by every hook.
/// - [AuthyraClientBuilder.setCallbacks], where an instance is registered.
abstract class AuthCallbacks {
  /// Called before sign-in starts.
  ///
  /// Return [CallbackResult.deny] to abort the sign-in before the provider
  /// is invoked. The denial reason is surfaced as an
  /// [AuthenticationFailedException].
  ///
  /// Common uses:
  /// - Rate-limit repeated failed attempts.
  /// - Block sign-in for banned users or IPs.
  /// - Verify device trust before allowing authentication.
  Future<CallbackResult> onBeforeSignIn(
    String providerName,
    AuthSignInParams? params,
  ) async {
    return const CallbackResult.allow();
  }

  /// Called after provider authentication but before the session is created.
  ///
  /// At this point the identity provider has confirmed the user's identity.
  /// Return [CallbackResult.deny] to reject the user before a session is
  /// written to storage (e.g., when the user exists in the IdP but not in
  /// your application database).
  ///
  /// Common uses:
  /// - Validate that the email domain matches an allow-list.
  /// - Check whether the user has an active record in the application DB.
  /// - Enforce custom business rules (subscription active, account not locked).
  Future<CallbackResult> onBeforeSessionCreate(
    AuthUser user,
    String providerName,
  ) async {
    return const CallbackResult.allow();
  }

  /// Called before sign-out is processed.
  ///
  /// Return [CallbackResult.deny] to abort the sign-out. Use sparingly;
  /// blocking sign-out is rarely the right UX pattern.
  ///
  /// Common uses:
  /// - Prompt to save unsaved changes before leaving.
  /// - Prevent sign-out in supervised / kiosk modes.
  /// - Clean up application-level resources before the session is cleared.
  Future<CallbackResult> onBeforeSignOut(
    AuthUser user,
  ) async {
    return const CallbackResult.allow();
  }

  /// Called before the active account is switched to [toUserId].
  ///
  /// Return [CallbackResult.deny] to keep the current active account.
  ///
  /// Common uses:
  /// - Verify that [toUserId] has the required permissions in the current
  ///   context (e.g., cannot switch to a read-only account mid-transaction).
  /// - Validate session state before switching.
  Future<CallbackResult> onBeforeAccountSwitch(
    AuthUser fromUser,
    String toUserId,
  ) async {
    return const CallbackResult.allow();
  }

  /// Called before a token refresh is attempted.
  ///
  /// Return [CallbackResult.deny] to prevent the refresh; the session will
  /// then be expired and [AuthState.unauthenticated] emitted.
  ///
  /// Common uses:
  /// - Verify server-side that the session is still valid before refreshing.
  /// - Check whether the refresh token has been revoked in a blacklist.
  /// - Enforce rate limits on refresh frequency.
  Future<CallbackResult> onBeforeTokenRefresh(
    AuthUser user,
    String refreshToken,
  ) async {
    return const CallbackResult.allow();
  }

  /// Called before an account is removed from the registry.
  ///
  /// Return [CallbackResult.deny] to keep the account in the registry.
  ///
  /// Common uses:
  /// - Require explicit user confirmation before account removal.
  /// - Prevent removal of the last remaining account.
  /// - Verify that the caller has permission to remove the account.
  Future<CallbackResult> onBeforeAccountRemove(
    AuthUser user,
  ) async {
    return const CallbackResult.allow();
  }
}
