import 'package:equatable/equatable.dart';

/// Represents a provider-linked account entry for an [AuthUser].
///
/// An [AuthAccount] records the *relationship* between a user and a specific
/// authentication provider, including the provider's own identifier for the
/// user and any token data returned at sign-in time.
///
/// ## Why this model exists
///
/// [AuthSession] is the *session* container (active tokens, expiry). [AuthAccount]
/// is the *identity link*; it answers "which Google account is this user?" and
/// stores the `provider_account_id` (e.g., Google `sub`, GitHub login), enabling
/// proper account-linking in future versions: one [AuthUser] can have multiple
/// [AuthAccount] entries, one per provider.
///
/// ## Auto-generated ID
///
/// When not provided explicitly, [AuthyraClient.signIn] generates the [id] as
/// `'${providerId}_${providerAccountId}'`.
///
/// ## Example
///
/// ```dart
/// final account = AuthAccount(
///   id: 'google_109876543210987654321',
///   userId: 'usr_01',
///   providerId: 'google',
///   providerAccountId: '109876543210987654321', // Google sub
///   accessToken: 'ya29.xxx',
///   providerData: {'hd': 'example.com'},
/// );
/// ```
///
/// See also:
/// - [AuthUser], the canonical user identity.
/// - [AuthSession], the token container for an active session.
/// - [AuthSignInResult], which bundles an [AuthAccount] with the sign-in.
class AuthAccount extends Equatable {
  /// Unique identifier for this account entry.
  ///
  /// Default format: `'${providerId}_${providerAccountId}'`.
  final String id;

  /// The [AuthUser.id] this account belongs to.
  final String userId;

  /// The [AuthProvider.id] that authenticated this account (e.g., `'google'`).
  final String providerId;

  /// The provider's own identifier for this user.
  ///
  /// Examples:
  /// - Google: OpenID Connect `sub` claim (`'109876543210987654321'`)
  /// - GitHub: numeric user ID or login (`'octocat'`)
  /// - Credentials: email address (`'alice@example.com'`)
  final String providerAccountId;

  /// Access token returned by the provider at sign-in time, if available.
  final String? accessToken;

  /// Refresh token returned by the provider at sign-in time, if available.
  final String? refreshToken;

  /// When [accessToken] expires, if known.
  final DateTime? tokenExpiresAt;

  /// Arbitrary provider-specific metadata (e.g., OAuth scopes, hosted domain).
  ///
  /// ```dart
  /// final account = AuthAccount(
  ///   ...,
  ///   providerData: {
  ///     'scope': 'email profile',
  ///     'hd': 'example.com',    // Google Workspace domain
  ///   },
  /// );
  /// ```
  final Map<String, dynamic> providerData;

  /// Creates an [AuthAccount].
  ///
  /// [id], [userId], [providerId], and [providerAccountId] are required.
  /// Token fields are optional; they may be absent for providers that manage
  /// tokens server-side or for accounts that were linked without a fresh sign-in.
  const AuthAccount({
    required this.id,
    required this.userId,
    required this.providerId,
    required this.providerAccountId,
    this.accessToken,
    this.refreshToken,
    this.tokenExpiresAt,
    this.providerData = const {},
  });

  /// Returns a copy of this account with the specified fields replaced.
  ///
  /// Unspecified fields retain their current values. Because [AuthAccount] is
  /// immutable, this is the only way to derive a modified instance; for
  /// example, to update token data after a provider-side token refresh.
  AuthAccount copyWith({
    String? id,
    String? userId,
    String? providerId,
    String? providerAccountId,
    String? accessToken,
    String? refreshToken,
    DateTime? tokenExpiresAt,
    Map<String, dynamic>? providerData,
  }) {
    return AuthAccount(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      providerId: providerId ?? this.providerId,
      providerAccountId: providerAccountId ?? this.providerAccountId,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      tokenExpiresAt: tokenExpiresAt ?? this.tokenExpiresAt,
      providerData: providerData ?? this.providerData,
    );
  }

  /// Serialises this account to a JSON-compatible map.
  ///
  /// Timestamps are encoded as ISO 8601 strings. Token fields are included
  /// as-is; store the output in an encrypted backend (see [AuthStorage]).
  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'providerId': providerId,
        'providerAccountId': providerAccountId,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'tokenExpiresAt': tokenExpiresAt?.toIso8601String(),
        'providerData': providerData,
      };

  /// Deserialises an [AuthAccount] from a JSON map.
  ///
  /// Throws a [TypeError] if required string fields (`id`, `userId`,
  /// `providerId`, `providerAccountId`) are missing or have the wrong type.
  /// Optional fields default to `null`; [providerData] defaults to an empty map.
  factory AuthAccount.fromJson(Map<String, dynamic> json) {
    return AuthAccount(
      id: json['id'] as String,
      userId: json['userId'] as String,
      providerId: json['providerId'] as String,
      providerAccountId: json['providerAccountId'] as String,
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      tokenExpiresAt: json['tokenExpiresAt'] != null
          ? DateTime.parse(json['tokenExpiresAt'] as String)
          : null,
      providerData:
          (json['providerData'] as Map<String, dynamic>?) ?? const {},
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        providerId,
        providerAccountId,
        accessToken,
        refreshToken,
        tokenExpiresAt,
        providerData,
      ];

  @override
  String toString() =>
      'AuthAccount(id: $id, userId: $userId, providerId: $providerId, '
      'providerAccountId: $providerAccountId)';
}
