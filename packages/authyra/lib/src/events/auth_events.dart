import 'package:authyra/src/models/auth_session.dart';
import 'package:authyra/src/models/auth_user.dart';

/// Base class for all auth events
abstract class AuthEvent {
  final DateTime timestamp;

  AuthEvent() : timestamp = DateTime.now();

  Map<String, dynamic> toJson();
}

/// Fired AFTER successful sign in
class SignInEvent extends AuthEvent {
  final AuthUser user;
  final String providerName;
  final bool isNewUser;
  final Duration duration;

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

/// Fired AFTER successful sign out
class SignOutEvent extends AuthEvent {
  final AuthUser user;
  final Duration sessionDuration;

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

/// Fired AFTER sign in fails
class SignInFailedEvent extends AuthEvent {
  final String providerName;
  final String errorMessage;
  final String? errorCode;

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

/// Fired AFTER account switch
class AccountSwitchEvent extends AuthEvent {
  final AuthUser fromUser;
  final AuthUser toUser;

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

/// Fired AFTER token refresh (success or failure)
class TokenRefreshEvent extends AuthEvent {
  final AuthUser user;
  final bool success;
  final String? errorMessage;

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

/// Fired AFTER session created
class SessionCreatedEvent extends AuthEvent {
  final AuthSession session;
  final bool isNewUser;

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

/// Fired AFTER session expires
class SessionExpiredEvent extends AuthEvent {
  final AuthUser user;
  final DateTime expiredAt;

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

/// Fired AFTER account removed
class AccountRemovedEvent extends AuthEvent {
  final String userId;
  final String email;

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
