import 'package:equatable/equatable.dart';
import 'package:authyra/src/models/auth_user.dart';

/// Represents an authenticated session with tokens and expiration
///
/// Immutable model that stores all authentication data for a single account.
/// Supports multiple providers through [linkedProviders].
class AuthSession extends Equatable {
  /// Primary authentication provider (e.g., 'google', 'github', 'email')
  final String providerId;

  /// User's profil
  final AuthUser user;

  /// Access token for API requests
  final String? accessToken;

  /// Refresh token for renewing access tokens
  final String? refreshToken;

  /// Timestamp when the access token expires
  final DateTime? expiresAt;

  /// List of linked authentication providers
  ///
  /// Example: ['google', 'github', 'email']
  final List<String> linkedProviders;

  /// Timestamp when the account was created
  final DateTime createdAt;

  /// Timestamp when the account was last updated
  final DateTime lastUsedAt;

  const AuthSession({
    required this.providerId,
    required this.user,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.linkedProviders = const [],
    required this.lastUsedAt,
    required this.createdAt,
  });

  /// Checks if the access token is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Checks if the access token will expire soon soon (within threshold)
  bool isExpiringSoon([Duration threshold = const Duration(minutes: 5)]) {
    if (expiresAt == null) return false;
    return DateTime.now().add(threshold).isAfter(expiresAt!);
  }

  /// Time remaining until expiration
  Duration get timeUntilExpiration {
    if (expiresAt == null) return Duration.zero;
    final now = DateTime.now();
    if (now.isAfter(expiresAt!)) return Duration.zero;
    return expiresAt!.difference(now);
  }

  /// Check if refresh token is available
  bool get canRefresh => refreshToken != null && refreshToken!.isNotEmpty;

  bool shouldRefresh({Duration threshold = const Duration(minutes: 5)}) {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!.subtract(threshold));
  }

  /// Checks if a provider is linked to this account
  bool hasLinkedProvider(String provider) {
    return linkedProviders.contains(provider);
  }

  /// Returns the namespace key for this account
  ///
  /// Used for cache isolation: "session:{userId}"
  String get namespaceKey {
    assert(user.id.isNotEmpty, 'User ID must not be empty for security isolation');
    return 'session:${user.id}';
  }

  /// Returns the cache namespace identifier
  ///
  /// Used by cache libraries (TanStack, Riverpod) for data isolation
  String get cacheNamespace => user.id;

  /// Update last used timestamp
  AuthSession markAsUsed() {
    return copyWith(lastUsedAt: DateTime.now());
  }

  /// Update tokens after refresh
  AuthSession refreshed({
    required String newAccessToken,
    String? newRefreshToken,
    required DateTime newExpiresAt,
  }) {
    return copyWith(
      accessToken: newAccessToken,
      refreshToken: newRefreshToken ?? refreshToken,
      expiresAt: newExpiresAt,
      lastUsedAt: DateTime.now(),
    );
  }

  AuthSession copyWith({
    String? providerId,
    AuthUser? user,
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    List<String>? linkedProviders,
    DateTime? createdAt,
    DateTime? lastUsedAt,
  }) {
    return AuthSession(
      providerId: providerId ?? this.providerId,
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      linkedProviders: linkedProviders ?? this.linkedProviders,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'providerId': providerId,
        'user': user.toJson(),
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt?.toIso8601String(),
        'linkedProviders': linkedProviders,
        'createdAt': createdAt.toIso8601String(),
        'lastUsedAt': lastUsedAt.toIso8601String(),
      };

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      providerId: json['providerId'] as String,
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      linkedProviders: (json['linkedProviders'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
      lastUsedAt: json['lastUsedAt'] != null ? DateTime.parse(json['lastUsedAt'] as String) : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        providerId,
        user,
        accessToken,
        refreshToken,
        expiresAt,
        linkedProviders,
        createdAt,
        lastUsedAt,
      ];

  @override
  String toString() =>
      'AuthSession(userId: ${user.id}, email: ${user.email}, providerId: $providerId, linkedProviders: $linkedProviders)';
}
