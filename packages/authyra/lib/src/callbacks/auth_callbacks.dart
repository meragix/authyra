import 'package:authyra/src/callbacks/callback_result.dart';
import 'package:authyra/src/interfaces/auth_sign_in_params.dart';
import 'package:authyra/src/models/auth_user.dart';

/// Callbacks are executed BEFORE an action
/// They can STOP the action if they return CallbackResult.deny()
abstract class AuthCallbacks {
  /// Called BEFORE sign in starts
  /// Return CallbackResult.deny() to prevent sign in
  ///
  /// Use cases:
  /// - Check if user is banned
  /// - Validate IP address
  /// - Check rate limiting
  /// - Verify device/browser
  Future<CallbackResult> onBeforeSignIn(
    String providerName,
    AuthSignInParams? params,
  ) async {
    return const CallbackResult.allow();
  }

  /// Called AFTER provider authentication but BEFORE session creation
  /// Return CallbackResult.deny() to reject the user
  ///
  /// Use cases:
  /// - Validate email domain (only @company.com)
  /// - Check if account exists in your DB
  /// - Verify user permissions
  /// - Apply custom business rules
  Future<CallbackResult> onBeforeSessionCreate(
    AuthUser user,
    String providerName,
  ) async {
    return const CallbackResult.allow();
  }

  /// Called BEFORE sign out
  /// Return CallbackResult.deny() to prevent sign out
  ///
  /// Use cases:
  /// - Confirm unsaved changes
  /// - Check if admin wants to logout
  /// - Cleanup resources
  Future<CallbackResult> onBeforeSignOut(
    AuthUser user,
  ) async {
    return const CallbackResult.allow();
  }

  /// Called BEFORE account switch
  /// Return CallbackResult.deny() to prevent switch
  ///
  /// Use cases:
  /// - Check if target account is active
  /// - Verify permissions to switch
  /// - Validate session state
  Future<CallbackResult> onBeforeAccountSwitch(
    AuthUser fromUser,
    String toUserId,
  ) async {
    return const CallbackResult.allow();
  }

  /// Called BEFORE token refresh
  /// Return CallbackResult.deny() to prevent refresh
  ///
  /// Use cases:
  /// - Check if session is still valid server-side
  /// - Verify refresh token hasn't been revoked
  /// - Check rate limiting on refreshes
  Future<CallbackResult> onBeforeTokenRefresh(
    AuthUser user,
    String refreshToken,
  ) async {
    return const CallbackResult.allow();
  }

  /// Called BEFORE removing an account
  /// Return CallbackResult.deny() to prevent removal
  ///
  /// Use cases:
  /// - Confirm user intent
  /// - Check if it's the last account
  /// - Verify permissions
  Future<CallbackResult> onBeforeAccountRemove(
    AuthUser user,
  ) async {
    return const CallbackResult.allow();
  }
}
