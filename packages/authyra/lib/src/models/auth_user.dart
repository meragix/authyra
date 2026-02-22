import 'package:equatable/equatable.dart';

/// Represents an authenticated user within the Authyra framework.
///
/// [AuthUser] is an **immutable value object** capturing identity and profile
/// data returned by an authentication provider. It is intentionally minimal —
/// provider-specific or domain-specific fields belong in [metadata].
///
/// ## Value equality
///
/// [AuthUser] extends [Equatable], so two instances with the same field values
/// compare as equal. This makes them safe to use in `Stream`-based reactive
/// pipelines (e.g., Riverpod, BLoC) without spurious rebuilds.
///
/// ## Example
///
/// ```dart
/// final user = AuthUser(
///   id: 'usr_01HXYZ',
///   email: 'alice@example.com',
///   name: 'Alice Dupont',
///   metadata: {'role': 'admin', 'tenantId': 'acme'},
/// );
///
/// print(user.displayName); // Alice Dupont
/// print(user.initials);    // AD
/// print(user.metadata['role']); // admin
/// ```
///
/// See also:
/// - [AuthSession], which wraps an [AuthUser] with access/refresh tokens.
/// - [AuthState], which reflects the current high-level authentication state.
class AuthUser extends Equatable {
  /// Unique identifier for this user.
  ///
  /// This is the canonical key used across [SessionRegistry] and for
  /// cache namespacing (see [AuthSession.namespaceKey]). Must be non-empty
  /// and stable across sessions — never reassigned by the provider.
  final String id;

  /// Primary email address, if disclosed by the provider.
  ///
  /// May be `null` for providers that do not expose an email address, or when
  /// the OAuth scope does not include `email`. Always validate before use.
  final String? email;

  /// Human-readable display name.
  ///
  /// Typically the full name as returned by the identity provider
  /// (e.g., Google profile name). Falls back gracefully via [displayName].
  final String? name;

  /// URL pointing to the user's profile avatar image.
  ///
  /// Useful for rendering avatars in UI components. When `null`, use
  /// [initials] to generate a text-based placeholder instead.
  final String? avatarUrl;

  /// Arbitrary key-value metadata attached to this user.
  ///
  /// Use this bag for domain-specific attributes such as roles, permissions,
  /// tenant identifiers, subscription tiers, or feature flags. All keys must
  /// be stable strings and all values must be JSON-serialisable.
  ///
  /// ```dart
  /// final user = AuthUser(
  ///   id: 'usr_01',
  ///   metadata: {
  ///     'role': 'admin',
  ///     'tenantId': 'acme-corp',
  ///     'plan': 'pro',
  ///   },
  /// );
  ///
  /// final isAdmin = user.metadata['role'] == 'admin';
  /// ```
  final Map<String, dynamic> metadata;

  /// Creates an [AuthUser].
  ///
  /// Only [id] is required. All other fields are optional to accommodate
  /// identity providers with varying levels of profile disclosure.
  const AuthUser({
    required this.id,
    this.email,
    this.name,
    this.avatarUrl,
    this.metadata = const {},
  });

  // ---------------------------------------------------------------------------
  // Derived properties
  // ---------------------------------------------------------------------------

  /// Resolves the best available display name for this user.
  ///
  /// Priority order: [name] → [email] → `'User $id'`.
  /// Never returns `null` — safe to render directly in UI.
  String get displayName => name ?? email ?? 'User $id';

  /// Two-letter initials derived from [name] or [email], for avatar fallbacks.
  ///
  /// Derivation rules (in priority order):
  /// 1. Full name with ≥ 2 words → first letters of first and last word.
  /// 2. Single-word name → first letter of that word.
  /// 3. No name, has email → first letter of the email address.
  /// 4. Neither → `'U'`.
  ///
  /// The result is always upper-cased.
  ///
  /// ```dart
  /// AuthUser(id: '1', name: 'Alice Dupont').initials; // 'AD'
  /// AuthUser(id: '2', name: 'Alice').initials;        // 'A'
  /// AuthUser(id: '3', email: 'bob@acme.com').initials; // 'B'
  /// AuthUser(id: '4').initials;                        // 'U'
  /// ```
  String get initials {
    if (name != null && name!.isNotEmpty) {
      final parts = name!.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      }
      return name![0].toUpperCase();
    }
    if (email != null && email!.isNotEmpty) {
      return email![0].toUpperCase();
    }
    return 'U';
  }

  // ---------------------------------------------------------------------------
  // Mutation
  // ---------------------------------------------------------------------------

  /// Returns a copy of this user with the specified fields replaced.
  ///
  /// Unspecified fields retain their current values. Because [AuthUser] is
  /// immutable, this is the only way to derive a modified instance.
  ///
  /// ```dart
  /// final updated = user.copyWith(name: 'Alice Martin');
  /// ```
  AuthUser copyWith({
    String? id,
    String? email,
    String? name,
    String? avatarUrl,
    Map<String, dynamic>? metadata,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      metadata: metadata ?? this.metadata,
    );
  }

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  /// Serialises this user to a JSON-compatible map.
  ///
  /// All scalar values are primitives or `null`. [metadata] is included
  /// as-is — ensure its contents are JSON-serialisable before calling this.
  ///
  /// ```dart
  /// final json = user.toJson();
  /// final restored = AuthUser.fromJson(json);
  /// assert(restored == user);
  /// ```
  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'avatarUrl': avatarUrl,
        'metadata': metadata,
      };

  /// Deserialises an [AuthUser] from a JSON map.
  ///
  /// Throws a [TypeError] if [json] is malformed (e.g., `'id'` is missing or
  /// not a `String`). The [metadata] field defaults to an empty map when
  /// absent.
  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String?,
      name: json['name'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
    );
  }

  // ---------------------------------------------------------------------------
  // Equatable / Object
  // ---------------------------------------------------------------------------

  @override
  List<Object?> get props => [id, email, name, avatarUrl, metadata];

  @override
  String toString() => 'AuthUser(id: $id, email: $email, name: $name)';
}
