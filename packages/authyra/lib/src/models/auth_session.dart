import 'package:equatable/equatable.dart';
import 'package:authyra/src/models/auth_account.dart';
import 'package:authyra/src/models/auth_user.dart';
import 'package:authyra/src/models/session_metadata.dart';

/// An active session for an [AuthUser], modelled as a **pointer** to the
/// current [AuthAccount].
///
/// [AuthSession] is an **immutable value object** that records *which* account
/// is active right now, together with session-scoped metadata and timestamps.
/// Token data ([accessToken], [refreshToken], [expiresAt]) are **not stored
/// directly** on the session; they are read from [activeAccount], which is the
/// entry in [linkedAccounts] identified by [activeAccountId].
///
/// ## Why "Session as a Pointer"
///
/// Keeping tokens in [AuthAccount] rather than on the session gives a single
/// source of truth: when [TokenRefresher] updates an account's tokens, every
/// consumer that reads `session.accessToken` immediately sees the new value
/// without needing to rebuild the session object. It also makes multi-provider
/// account-switching trivial: changing [activeAccountId] switches which set of
/// tokens is in use.
///
/// ## Lifecycle
///
/// ```
/// sign-in → AuthSession created with activeAccountId pointing to primary account
///         → [isExpiringSoon] triggers proactive refresh via TokenRefresher
///         → [refreshed] updates tokens inside the active AuthAccount
///         → sign-out → session discarded from [SessionRegistry]
/// ```
///
/// ## Multi-provider support
///
/// One user can authenticate through multiple providers. Each is stored as an
/// [AuthAccount] in [linkedAccounts]. [activeAccountId] identifies which one
/// is currently used for token operations. Switching accounts means creating a
/// new session via [copyWith] with a different [activeAccountId].
///
/// ```dart
/// // Reading the active token — transparently reads from activeAccount.
/// final token = session.accessToken;
///
/// // Checking expiry.
/// if (session.isExpiringSoon()) {
///   final refreshed = await client.refreshSession();
/// }
///
/// // Switching to a linked provider.
/// final withGithub = session.copyWith(
///   activeAccountId: session.linkedAccounts
///       .firstWhere((a) => a.providerId == 'github').id,
/// );
/// ```
///
/// See also:
/// - [AuthUser], the identity payload embedded in every session.
/// - [AuthAccount], the provider-linked account entries that hold tokens.
/// - [SessionMetadata], the optional device/network context.
/// - [SessionRegistry], the in-memory store for multi-account sessions.
class AuthSession extends Equatable {
  /// User's identity profile for this session.
  final AuthUser user;

  /// The [AuthAccount.id] of the currently active provider account.
  ///
  /// Must match one entry in [linkedAccounts]. All token-related operations
  /// ([accessToken], [refreshToken], [expiresAt], [refreshed]) read from and
  /// write to the account identified by this ID.
  final String activeAccountId;

  /// All provider-linked accounts for this user.
  ///
  /// Each entry represents a provider connected to this user. The active
  /// account ([activeAccountId]) is typically the first entry. Additional
  /// entries are added via account-linking flows.
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
  /// [user], [activeAccountId], [createdAt], and [lastUsedAt] are required.
  /// [activeAccountId] must reference an entry in [linkedAccounts] so that
  /// token getters resolve correctly.
  const AuthSession({
    required this.user,
    required this.activeAccountId,
    this.linkedAccounts = const [],
    this.metadata,
    required this.createdAt,
    required this.lastUsedAt,
  });

  // ---------------------------------------------------------------------------
  // Active account accessor
  // ---------------------------------------------------------------------------

  /// The currently active [AuthAccount], or `null` if [activeAccountId] is not
  /// found in [linkedAccounts].
  ///
  /// All token getters ([accessToken], [refreshToken], [expiresAt],
  /// [providerId]) delegate to this account.
  AuthAccount? get activeAccount {
    for (final account in linkedAccounts) {
      if (account.id == activeAccountId) return account;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Computed token fields (delegate to active account)
  // ---------------------------------------------------------------------------

  /// Primary authentication provider identifier; derived from [activeAccount].
  ///
  /// Lowercase slug (e.g., `'google'`, `'github'`, `'email'`). Returns an
  /// empty string when [activeAccount] is `null`.
  String get providerId => activeAccount?.providerId ?? '';

  /// Short-lived access token for the active account.
  ///
  /// `null` for session-cookie-based flows where the token is managed
  /// server-side and not exposed to the client.
  String? get accessToken => activeAccount?.accessToken;

  /// Long-lived refresh token for the active account.
  ///
  /// When non-null and non-empty (see [canRefresh]), the session can be
  /// silently renewed without requiring the user to re-authenticate.
  String? get refreshToken => activeAccount?.refreshToken;

  /// UTC timestamp at which [accessToken] expires.
  ///
  /// `null` means the token has no known expiry (treat as non-expiring or
  /// rely on server-side enforcement).
  DateTime? get expiresAt => activeAccount?.tokenExpiresAt;

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
  ///   session = await client.refreshSession();
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
  /// Semantically equivalent to [isExpiringSoon] but accepts a named
  /// parameter, making it ergonomic in configuration-driven auto-refresh logic.
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

  /// Returns a copy of this session with updated tokens applied to the active
  /// account.
  ///
  /// Finds the account matching [activeAccountId] in [linkedAccounts] and
  /// returns a new session where that account's `accessToken`, `refreshToken`,
  /// and `tokenExpiresAt` are replaced. All other accounts are unchanged.
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
    final updatedAccounts = linkedAccounts.map((a) {
      if (a.id == activeAccountId) {
        return a.copyWith(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken ?? a.refreshToken,
          tokenExpiresAt: newExpiresAt,
        );
      }
      return a;
    }).toList();
    return copyWith(
      linkedAccounts: updatedAccounts,
      lastUsedAt: DateTime.now(),
    );
  }

  /// Returns a copy of this session with the specified fields replaced.
  ///
  /// Fields not specified retain their current values.
  AuthSession copyWith({
    AuthUser? user,
    String? activeAccountId,
    List<AuthAccount>? linkedAccounts,
    SessionMetadata? metadata,
    DateTime? createdAt,
    DateTime? lastUsedAt,
  }) {
    return AuthSession(
      user: user ?? this.user,
      activeAccountId: activeAccountId ?? this.activeAccountId,
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
  /// Timestamps are encoded as ISO 8601 strings. Token data is not stored
  /// directly here; it lives inside [linkedAccounts]. Ensure the output is
  /// stored securely (encrypted storage, never plain localStorage in browser
  /// environments).
  Map<String, dynamic> toJson() => {
        'user': user.toJson(),
        'activeAccountId': activeAccountId,
        'linkedAccounts': linkedAccounts.map((a) => a.toJson()).toList(),
        'metadata': metadata?.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'lastUsedAt': lastUsedAt.toIso8601String(),
      };

  /// Deserialises an [AuthSession] from a JSON map.
  ///
  /// - [activeAccountId] falls back to the first linked account's ID when
  ///   absent; this handles sessions persisted before this field was introduced.
  /// - Legacy sessions with `providerId` + top-level tokens are migrated
  ///   gracefully: the tokens are read from [linkedAccounts] via the resolved
  ///   [activeAccountId].
  /// - [createdAt] and [lastUsedAt] fall back to [DateTime.now] when absent,
  ///   which is safe for sessions migrated from older storage formats.
  factory AuthSession.fromJson(Map<String, dynamic> json) {
    // Deserialise linkedAccounts.
    List<AuthAccount> linkedAccounts = const [];
    final raw = json['linkedAccounts'];
    if (raw is List) {
      linkedAccounts = raw
          .whereType<Map<String, dynamic>>()
          .map(AuthAccount.fromJson)
          .toList();
    }

    // Resolve activeAccountId — gracefully handle pre-migration sessions.
    String activeAccountId = json['activeAccountId'] as String? ?? '';
    if (activeAccountId.isEmpty && linkedAccounts.isNotEmpty) {
      activeAccountId = linkedAccounts.first.id;
    }
    if (activeAccountId.isEmpty) {
      // Last resort: reconstruct from legacy providerId + userId fields.
      final legacyProviderId = json['providerId'] as String? ?? '';
      final userId =
          (json['user'] as Map<String, dynamic>?)?['id'] as String? ?? '';
      activeAccountId = '${legacyProviderId}_$userId';
    }

    return AuthSession(
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      activeAccountId: activeAccountId,
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
        user,
        activeAccountId,
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
