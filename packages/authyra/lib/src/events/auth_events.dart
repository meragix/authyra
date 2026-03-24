import 'package:authyra/src/models/auth_session.dart';
import 'package:authyra/src/models/auth_user.dart';

/// Base class for all Authyra authentication events.
///
/// Events are emitted by [AuthyraClient] after each significant auth action
/// and broadcast through [AuthEventBus]. Subscribe via [AuthEventBus.on] for
/// typed handlers, or [AuthEventBus.stream] for raw access to all events.
///
/// All concrete events carry a [timestamp] set to [DateTime.now] at
/// construction time.
///
/// ## Event catalogue
///
/// | Event                 | Emitted when                              |
/// |-----------------------|-------------------------------------------|
/// | [SignInEvent]         | Sign-in succeeded                         |
/// | [SignOutEvent]        | Sign-out completed                        |
/// | [SignInFailedEvent]   | Sign-in attempt failed                    |
/// | [AccountSwitchEvent]  | Active account changed                    |
/// | [TokenRefreshEvent]   | Token refresh succeeded or failed         |
/// | [SessionCreatedEvent] | New session created in the registry       |
/// | [SessionExpiredEvent] | Session expired and was cleared           |
/// | [AccountRemovedEvent] | Account removed from the registry         |
///
/// ## Listening to events
///
/// ```dart
/// // Typed subscription
/// client.events.on<SignInEvent>((e) {
///   analytics.track('sign_in', {'provider': e.providerName});
/// });
///
/// // Raw stream (all events, useful for audit logging)
/// client.events.stream.listen((e) {
///   auditLog.write(e.toJson());
/// });
/// ```
///
/// See also:
/// - [AuthEventBus], the bus that broadcasts these events.
/// - [AuthyraClient.events], the public accessor to the bus.
abstract class AuthEvent {
  /// UTC timestamp at which this event was created.
  final DateTime timestamp;

  /// Creates an [AuthEvent] with [timestamp] set to [DateTime.now].
  AuthEvent() : timestamp = DateTime.now();

  /// Serialises this event to a JSON-compatible map.
  ///
  /// Keys use `snake_case` to match standard audit log conventions.
  /// Always includes `'event'` (the event type slug) and `'timestamp'`
  /// (ISO 8601 string).
  Map<String, dynamic> toJson();
}

// ---------------------------------------------------------------------------
// Sign-in
// ---------------------------------------------------------------------------

/// Emitted after a successful sign-in.
///
/// Carries the authenticated [user], the [providerName] that handled the
/// sign-in, whether this was a [isNewUser] first-time sign-in, and the
/// round-trip [duration].
///
/// ```dart
/// client.events.on<SignInEvent>((e) {
///   if (e.isNewUser) onboarding.start(e.user);
///   metrics.recordSignIn(e.providerName, e.duration);
/// });
/// ```
class SignInEvent extends AuthEvent {
  /// The authenticated user.
  final AuthUser user;

  /// The [AuthProvider.id] that handled this sign-in (e.g., `'google'`).
  final String providerName;

  /// Whether this is the user's first sign-in (no prior session existed).
  final bool isNewUser;

  /// Total time from the start of [AuthyraClient.signIn] to completion.
  final Duration duration;

  /// Creates a [SignInEvent].
  SignInEvent({
    required this.user,
    required this.providerName,
    required this.isNewUser,
    required this.duration,
  });

  @override
  Map<String, dynamic> toJson() => {
        'event': 'sign_in',
        'user_id': user.id,
        'email': user.email,
        'provider': providerName,
        'is_new_user': isNewUser,
        'duration_ms': duration.inMilliseconds,
        'timestamp': timestamp.toIso8601String(),
      };
}

// ---------------------------------------------------------------------------
// Sign-out
// ---------------------------------------------------------------------------

/// Emitted after a successful sign-out.
///
/// ```dart
/// client.events.on<SignOutEvent>((e) {
///   analytics.track('sign_out', {'session_minutes': e.sessionDuration.inMinutes});
/// });
/// ```
class SignOutEvent extends AuthEvent {
  /// The user who signed out.
  final AuthUser user;

  /// How long the session was active, from creation to sign-out.
  final Duration sessionDuration;

  /// Creates a [SignOutEvent].
  SignOutEvent({
    required this.user,
    required this.sessionDuration,
  });

  @override
  Map<String, dynamic> toJson() => {
        'event': 'sign_out',
        'user_id': user.id,
        'session_duration_minutes': sessionDuration.inMinutes,
        'timestamp': timestamp.toIso8601String(),
      };
}

// ---------------------------------------------------------------------------
// Sign-in failed
// ---------------------------------------------------------------------------

/// Emitted when a sign-in attempt fails.
///
/// Fired for both expected failures (wrong password, cancelled OAuth flow) and
/// unexpected errors (network failure, provider misconfiguration). Inspect
/// [errorCode] for machine-readable classification.
///
/// ```dart
/// client.events.on<SignInFailedEvent>((e) {
///   logger.warn('Sign-in failed via ${e.providerName}: ${e.errorMessage}');
/// });
/// ```
class SignInFailedEvent extends AuthEvent {
  /// The [AuthProvider.id] that rejected the sign-in.
  final String providerName;

  /// Human-readable description of the failure.
  final String errorMessage;

  /// Optional machine-readable error code from the [AuthException].
  ///
  /// Examples: `'AUTH_FAILED'`, `'PROVIDER_NOT_FOUND'`, `'INVALID_CONFIG'`.
  final String? errorCode;

  /// Creates a [SignInFailedEvent].
  SignInFailedEvent({
    required this.providerName,
    required this.errorMessage,
    this.errorCode,
  });

  @override
  Map<String, dynamic> toJson() => {
        'event': 'sign_in_failed',
        'provider': providerName,
        'error': errorMessage,
        'error_code': errorCode,
        'timestamp': timestamp.toIso8601String(),
      };
}

// ---------------------------------------------------------------------------
// Account switch
// ---------------------------------------------------------------------------

/// Emitted after the active account is switched.
///
/// ```dart
/// client.events.on<AccountSwitchEvent>((e) {
///   print('Switched from ${e.fromUser.email} to ${e.toUser.email}');
/// });
/// ```
class AccountSwitchEvent extends AuthEvent {
  /// The user that was active before the switch.
  final AuthUser fromUser;

  /// The user that is now active.
  final AuthUser toUser;

  /// Creates an [AccountSwitchEvent].
  AccountSwitchEvent({
    required this.fromUser,
    required this.toUser,
  });

  @override
  Map<String, dynamic> toJson() => {
        'event': 'account_switch',
        'from_user_id': fromUser.id,
        'to_user_id': toUser.id,
        'timestamp': timestamp.toIso8601String(),
      };
}

// ---------------------------------------------------------------------------
// Token refresh
// ---------------------------------------------------------------------------

/// Emitted after a token refresh attempt, whether it succeeded or failed.
///
/// When [success] is `false`, the session has been cleared and
/// [AuthState.unauthenticated] emitted. Check [errorMessage] for the reason.
///
/// ```dart
/// client.events.on<TokenRefreshEvent>((e) {
///   if (!e.success) showReAuthPrompt(e.user);
/// });
/// ```
class TokenRefreshEvent extends AuthEvent {
  /// The user whose access token was being refreshed.
  final AuthUser user;

  /// Whether the refresh succeeded and new tokens were applied.
  final bool success;

  /// Human-readable failure reason when [success] is `false`.
  final String? errorMessage;

  /// Creates a [TokenRefreshEvent].
  TokenRefreshEvent({
    required this.user,
    required this.success,
    this.errorMessage,
  });

  @override
  Map<String, dynamic> toJson() => {
        'event': 'token_refresh',
        'user_id': user.id,
        'success': success,
        'error': errorMessage,
        'timestamp': timestamp.toIso8601String(),
      };
}

// ---------------------------------------------------------------------------
// Session created
// ---------------------------------------------------------------------------

/// Emitted when a new [AuthSession] is written to the registry.
///
/// Fired both for first-time sign-ins ([isNewUser] `true`) and repeated
/// sign-ins that refresh an existing session ([isNewUser] `false`).
///
/// ```dart
/// client.events.on<SessionCreatedEvent>((e) {
///   if (e.isNewUser) provisionUserInDb(e.session.user);
/// });
/// ```
class SessionCreatedEvent extends AuthEvent {
  /// The newly created or refreshed session.
  final AuthSession session;

  /// Whether this is the user's first session (no prior entry existed).
  final bool isNewUser;

  /// Creates a [SessionCreatedEvent].
  SessionCreatedEvent({
    required this.session,
    required this.isNewUser,
  });

  @override
  Map<String, dynamic> toJson() => {
        'event': 'session_created',
        'user_id': session.user.id,
        'is_new_user': isNewUser,
        'expires_at': session.expiresAt?.toIso8601String(),
        'timestamp': timestamp.toIso8601String(),
      };
}

// ---------------------------------------------------------------------------
// Session expired
// ---------------------------------------------------------------------------

/// Emitted when an active session expires and is cleared from the registry.
///
/// After this event [AuthState.unauthenticated] is emitted. Use it to prompt
/// the user to re-authenticate or to clean up session-scoped resources.
///
/// ```dart
/// client.events.on<SessionExpiredEvent>((e) {
///   showSnackBar('Your session expired. Please sign in again.');
/// });
/// ```
class SessionExpiredEvent extends AuthEvent {
  /// The user whose session expired.
  final AuthUser user;

  /// The UTC timestamp at which the session expired.
  final DateTime expiredAt;

  /// Creates a [SessionExpiredEvent].
  SessionExpiredEvent({
    required this.user,
    required this.expiredAt,
  });

  @override
  Map<String, dynamic> toJson() => {
        'event': 'session_expired',
        'user_id': user.id,
        'expired_at': expiredAt.toIso8601String(),
        'timestamp': timestamp.toIso8601String(),
      };
}

// ---------------------------------------------------------------------------
// Account removed
// ---------------------------------------------------------------------------

/// Emitted when an account is explicitly removed from the registry.
///
/// Distinct from [SessionExpiredEvent]: this event is fired by a deliberate
/// account-removal action, not by token expiry.
///
/// ```dart
/// client.events.on<AccountRemovedEvent>((e) {
///   myDb.revokeDeviceAccess(userId: e.userId);
/// });
/// ```
class AccountRemovedEvent extends AuthEvent {
  /// The [AuthUser.id] of the removed account.
  final String userId;

  /// The email address of the removed account.
  final String email;

  /// Creates an [AccountRemovedEvent].
  AccountRemovedEvent({
    required this.userId,
    required this.email,
  });

  @override
  Map<String, dynamic> toJson() => {
        'event': 'account_removed',
        'user_id': userId,
        'email': email,
        'timestamp': timestamp.toIso8601String(),
      };
}
