import 'package:equatable/equatable.dart';
import 'package:authyra/src/models/auth_account.dart';
import 'package:authyra/src/models/auth_user.dart';
import 'package:authyra/src/models/session_metadata.dart';

/// Represents an authenticated session containing tokens and user identity.
///
/// [AuthSession] is an **immutable value object** that stores all
/// authentication data for a single account: the associated [AuthUser],
/// access/refresh tokens, expiry metadata, linked [AuthAccount] entries,
/// and optional [SessionMetadata].
///
/// ## Lifecycle
///
/// ```
/// sign-in → AuthSession created
///         → [isExpiringSoon] triggers proactive refresh
///         → [refreshed] returns new session with updated tokens
///         → sign-out → session discarded from [SessionRegistry]
/// ```
///
/// ## Multi-provider support
///
/// A single user can authenticate through multiple providers. The primary
/// provider is stored in [providerId]; all linked provider accounts are
/// listed in [linkedAccounts].
///
/// ```dart
/// final session = AuthSession(
///   providerId: 'google',
///   user: user,
///   accessToken: 'ya29.xxx',
///   expiresAt: DateTime.now().add(const Duration(hours: 1)),
///   createdAt: DateTime.now(),
///   lastUsedAt: DateTime.now(),
/// );
///
/// if (session.isExpiringSoon()) {
///   final refreshed = await client.refresh(session);
/// }
/// ```
///
/// See also:
/// - [AuthUser], the identity payload embedded in every session.
/// - [AuthAccount], the provider-linked account entries.
/// - [SessionMetadata], the optional device/network context.
/// - [SessionRegistry], the in-memory store for multi-account sessions.
class AuthSession extends Equatable {
  /// Primary authentication provider identifier.
  ///
  /// Lowercase slug (e.g., `'google'`, `'github'`, `'email'`). Matches the
  /// `providerId` declared on the corresponding [AuthProvider].
  final String providerId;

  /// User's identity profile for this session.
  final AuthUser user;

  /// Short-lived access token used to authenticate API requests.
  ///
  /// May be `null` for session-cookie-based flows where the token is
  /// managed server-side and not exposed to the client.
  final String? accessToken;

  /// Long-lived refresh token used to obtain new access tokens.
  ///
  /// When non-null and non-empty (see [canRefresh]), the session can be
  /// silently renewed without requiring the user to re-authenticate.
  final String? refreshToken;

  /// UTC timestamp at which [accessToken] expires.
  ///
  /// `null` means the token has no known expiry (treat as non-expiring or
  /// rely on server-side enforcement).
  final DateTime? expiresAt;

  /// All provider-linked accounts for this user.
  ///
  /// Each entry represents a provider that has been connected to this user.
  /// The primary account (for [providerId]) is typically the first entry.
  /// Additional entries are added via account-linking flows.
  ///
  /// Use [linkedProviderIds] for a quick set of connected provider IDs.
  final List<AuthAccount> linkedAccounts;

  /// Optional device and network context captured at session creation.
  ///
  /// Populated via [AuthCallbacks.onBeforeSessionCreate]. Never read
  /// internally by Authyra; surfaced to consumers for audit logs,
  /// fraud detection, or device management UIs.
  final SessionMetadata? metadata;

  /// UTC timestamp when this session was first created.
  final DateTime createdAt;

  /// UTC timestamp of the most recent activity on this session.
  ///
  /// Updated by [markAsUsed] and [refreshed]. Used by [SessionRegistry]
  /// to sort accounts by recency and to elect a new active account when
  /// the current one is removed.
  final DateTime lastUsedAt;

  /// Creates an [AuthSession].
  ///
  /// [providerId], [user], [createdAt], and [lastUsedAt] are required.
  /// Token fields are optional to support cookie-based flows.
  const AuthSession({
    required this.providerId,
    required this.user,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.linkedAccounts = const [],
    this.metadata,
    required this.createdAt,
    required this.lastUsedAt,
  });

  // ---------------------------------------------------------------------------
  // Expiry helpers
  // ---------------------------------------------------------------------------

  /// Whether the [accessToken] has already expired.
  ///
  /// Returns `false` when [expiresAt] is `null` (no known expiry).
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Whether the [accessToken] will expire within [threshold].
  ///
  /// Defaults to a 5-minute window. Use this to trigger a proactive refresh
  /// before the token actually expires, avoiding failed API requests.
  ///
  /// Returns `false` when [expiresAt] is `null`.
  ///
  /// ```dart
  /// if (session.isExpiringSoon(const Duration(minutes: 10))) {
  ///   session = await client.refresh(session);
  /// }
  /// ```
  ///
  /// See also: [shouldRefresh], which expresses the same check with a named
  /// parameter for use in configuration-driven contexts.
  bool isExpiringSoon([Duration threshold = const Duration(minutes: 5)]) {
    if (expiresAt == null) return false;
    return DateTime.now().add(threshold).isAfter(expiresAt!);
  }

  /// Whether the session should be refreshed given a configurable [threshold].
  ///
  /// Semantically equivalent to [isExpiringSoon] but accepts a named parameter,
  /// making it ergonomic in configuration-driven auto-refresh logic.
  ///
  /// ```dart
  /// // Used internally by AuthyraClient's auto-refresh logic:
  /// if (session.shouldRefresh(threshold: config.refreshThreshold)) {
  ///   await client.refreshSession();
  /// }
  /// ```
  ///
  /// Returns `false` when [expiresAt] is `null`.
  bool shouldRefresh({Duration threshold = const Duration(minutes: 5)}) {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!.subtract(threshold));
  }

  /// Duration remaining until [accessToken] expiration.
  ///
  /// Returns [Duration.zero] if already expired or when [expiresAt] is `null`.
  Duration get timeUntilExpiration {
    if (expiresAt == null) return Duration.zero;
    final now = DateTime.now();
    if (now.isAfter(expiresAt!)) return Duration.zero;
    return expiresAt!.difference(now);
  }

  // ---------------------------------------------------------------------------
  // Capability checks
  // ---------------------------------------------------------------------------

  /// Whether a refresh token is available to renew the access token silently.
  bool get canRefresh => refreshToken != null && refreshToken!.isNotEmpty;

  /// The session's expiry time, or [DateTime.now] if no expiry is set.
  ///
  /// Use this when you need a non-nullable timestamp for sorting or scheduling,
  /// but cannot assume an expiry exists (e.g., cookie-based sessions).
  DateTime get expirationOrNow => expiresAt ?? DateTime.now();

  /// Set of provider IDs linked to this account.
  ///
  /// Convenience shorthand over [linkedAccounts].
  ///
  /// ```dart
  /// if (session.linkedProviderIds.contains('github')) {
  ///   showGitHubConnectionBadge();
  /// }
  /// ```
  Set<String> get linkedProviderIds =>
      linkedAccounts.map((a) => a.providerId).toSet();

  /// Whether the provider identified by [providerId] is linked to this account.
  ///
  /// Shorthand for `linkedProviderIds.contains(providerId)`.
  bool hasLinkedProvider(String providerId) =>
      linkedProviderIds.contains(providerId);

  // ---------------------------------------------------------------------------
  // Cache / namespace helpers
  // ---------------------------------------------------------------------------

  /// Cache key for this session, formatted as `session:{userId}`.
  ///
  /// Guarantees per-user isolation in shared caches (Redis, Hive, etc.).
  /// Asserts that [AuthUser.id] is non-empty as a defence-in-depth check.
  String get namespaceKey {
    assert(user.id.isNotEmpty, 'User ID must not be empty for cache isolation');
    return 'session:${user.id}';
  }

  /// The user ID used as the cache namespace identifier.
  ///
  /// Consumed by cache adapters (e.g., Riverpod family, TanStack Query) to
  /// scope cached data per authenticated user.
  String get cacheNamespace => user.id;

  // ---------------------------------------------------------------------------
  // Mutation helpers
  // ---------------------------------------------------------------------------

  /// Returns a copy of this session with [lastUsedAt] set to now.
  ///
  /// Call this whenever the session is accessed to maintain accurate
  /// recency ordering in [SessionRegistry].
  AuthSession markAsUsed() => copyWith(lastUsedAt: DateTime.now());

  /// Returns a copy of this session with updated tokens after a refresh.
  ///
  /// [newRefreshToken] is optional; when omitted, the existing [refreshToken]
  /// is preserved (common in rotating-token flows where only the access token
  /// changes).
  ///
  /// ```dart
  /// final renewed = session.refreshed(
  ///   newAccessToken: response.accessToken,
  ///   newExpiresAt: response.expiresAt,
  /// );
  /// ```
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

  /// Returns a copy of this session with the specified fields replaced.
  ///
  /// Fields not specified retain their current values.
  AuthSession copyWith({
    String? providerId,
    AuthUser? user,
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    List<AuthAccount>? linkedAccounts,
    SessionMetadata? metadata,
    DateTime? createdAt,
    DateTime? lastUsedAt,
  }) {
    return AuthSession(
      providerId: providerId ?? this.providerId,
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      linkedAccounts: linkedAccounts ?? this.linkedAccounts,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  /// Serialises this session to a JSON-compatible map.
  ///
  /// Timestamps are encoded as ISO 8601 strings. [accessToken] and
  /// [refreshToken] are included; ensure the output is stored securely
  /// (encrypted storage, never plain localStorage in browser environments).
  Map<String, dynamic> toJson() => {
        'providerId': providerId,
        'user': user.toJson(),
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt?.toIso8601String(),
        'linkedAccounts': linkedAccounts.map((a) => a.toJson()).toList(),
        'metadata': metadata?.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'lastUsedAt': lastUsedAt.toIso8601String(),
      };

  /// Deserialises an [AuthSession] from a JSON map.
  ///
  /// - [accessToken] and [refreshToken] are treated as nullable.
  /// - [expiresAt] is nullable; an absent or `null` value means no known expiry.
  /// - [createdAt] and [lastUsedAt] fall back to [DateTime.now] when absent,
  ///   which is safe for sessions migrated from older storage formats.
  /// - Legacy sessions with `linkedProviders` as `List<String>` are migrated
  ///   to empty [linkedAccounts] gracefully.
  factory AuthSession.fromJson(Map<String, dynamic> json) {
    // Deserialise linkedAccounts — gracefully handle legacy List<String> format.
    List<AuthAccount> linkedAccounts = const [];
    final raw = json['linkedAccounts'];
    if (raw is List) {
      linkedAccounts = raw
          .whereType<Map<String, dynamic>>()
          .map(AuthAccount.fromJson)
          .toList();
    }

    return AuthSession(
      providerId: json['providerId'] as String,
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      linkedAccounts: linkedAccounts,
      metadata: json['metadata'] != null
          ? SessionMetadata.fromJson(
              json['metadata'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.parse(json['lastUsedAt'] as String)
          : DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // Equatable / Object
  // ---------------------------------------------------------------------------

  @override
  List<Object?> get props => [
        providerId,
        user,
        accessToken,
        refreshToken,
        expiresAt,
        linkedAccounts,
        metadata,
        createdAt,
        lastUsedAt,
      ];

  @override
  String toString() =>
      'AuthSession(userId: ${user.id}, provider: $providerId, '
      'expired: $isExpired, linkedAccounts: ${linkedAccounts.length})';
}
