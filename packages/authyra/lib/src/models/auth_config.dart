import 'package:equatable/equatable.dart';

/// Configuration for an [AuthyraClient] instance.
///
/// [AuthConfig] is an **immutable value object** that controls token lifecycle
/// behaviour. Pass it when constructing an [AuthyraClient] to override the
/// opinionated defaults, or use [copyWith] to derive specialised configs for
/// different environments (dev, staging, prod).
///
/// ## Defaults
///
/// | Field                | Default       | Notes                                 |
/// |----------------------|---------------|---------------------------------------|
/// | [tokenLifetime]      | `3600` s      | 1-hour access tokens                  |
/// | [autoRefresh]        | `true`        | Proactive refresh enabled             |
/// | [refreshBeforeExpiry]| `300` s       | Refresh 5 minutes before expiry       |
///
/// ## Example
///
/// ```dart
/// final client = AuthyraClient(
///   storage: MySecureStorage(),
///   config: const AuthConfig(
///     tokenLifetime: 1800,       // 30-minute tokens
///     refreshBeforeExpiry: 120,  // Refresh 2 minutes early
///   ),
/// );
/// ```
///
/// ## Environment-specific overrides
///
/// ```dart
/// const base = AuthConfig();
///
/// // Disable auto-refresh in CLI / backend contexts that manage tokens manually
/// final backendConfig = base.copyWith(autoRefresh: false);
/// ```
///
/// See also:
/// - [AuthSession.shouldRefresh], which consumes [refreshBeforeExpiry] at
///   runtime to decide whether a proactive refresh is needed.
class AuthConfig extends Equatable {
  /// Nominal lifetime of an access token, in seconds.
  ///
  /// This value is used as a fallback when the provider does not return an
  /// explicit expiry timestamp. For providers that do return `expires_in`,
  /// the server-reported value takes precedence.
  ///
  /// Defaults to `3600` (1 hour).
  final int tokenLifetime;

  /// Whether to automatically refresh the access token before it expires.
  ///
  /// When `true`, `AuthyraInstance` schedules a silent refresh
  /// [refreshBeforeExpiry] seconds before expiry. Set to `false` in
  /// non-interactive contexts (backend services, CLI tools) where you prefer
  /// to manage token renewal explicitly.
  ///
  /// Defaults to `true`.
  final bool autoRefresh;

  /// How many seconds before expiry to trigger a proactive token refresh.
  ///
  /// Only meaningful when [autoRefresh] is `true`. A larger value gives more
  /// headroom at the cost of slightly shorter effective token lifetimes.
  ///
  /// Defaults to `300` (5 minutes).
  final int refreshBeforeExpiry;

  /// Creates an [AuthConfig].
  ///
  /// All parameters are optional; the defaults are sensible for most
  /// Flutter and Dart applications.
  const AuthConfig({
    this.tokenLifetime = 3600,
    this.autoRefresh = true,
    this.refreshBeforeExpiry = 300,
  });

  // ---------------------------------------------------------------------------
  // Derived helpers
  // ---------------------------------------------------------------------------

  /// [refreshBeforeExpiry] expressed as a [Duration].
  ///
  /// Convenience accessor for use with [AuthSession.shouldRefresh].
  ///
  /// ```dart
  /// session.shouldRefresh(threshold: config.refreshThreshold);
  /// ```
  Duration get refreshThreshold => Duration(seconds: refreshBeforeExpiry);

  /// [tokenLifetime] expressed as a [Duration].
  Duration get tokenLifetimeDuration => Duration(seconds: tokenLifetime);

  // ---------------------------------------------------------------------------
  // Mutation
  // ---------------------------------------------------------------------------

  /// Returns a copy of this config with the specified fields replaced.
  ///
  /// ```dart
  /// final devConfig = const AuthConfig().copyWith(autoRefresh: false);
  /// ```
  AuthConfig copyWith({
    int? tokenLifetime,
    bool? autoRefresh,
    int? refreshBeforeExpiry,
  }) {
    return AuthConfig(
      tokenLifetime: tokenLifetime ?? this.tokenLifetime,
      autoRefresh: autoRefresh ?? this.autoRefresh,
      refreshBeforeExpiry: refreshBeforeExpiry ?? this.refreshBeforeExpiry,
    );
  }

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  /// Serialises this config to a JSON-compatible map.
  ///
  /// Useful for persisting configuration alongside session data.
  Map<String, dynamic> toJson() => {
        'tokenLifetime': tokenLifetime,
        'autoRefresh': autoRefresh,
        'refreshBeforeExpiry': refreshBeforeExpiry,
      };

  /// Deserialises an [AuthConfig] from a JSON map.
  ///
  /// Missing fields fall back to their defaults, making this forward-compatible
  /// with older serialised configs that may lack newer fields.
  factory AuthConfig.fromJson(Map<String, dynamic> json) {
    return AuthConfig(
      tokenLifetime: json['tokenLifetime'] as int? ?? 3600,
      autoRefresh: json['autoRefresh'] as bool? ?? true,
      refreshBeforeExpiry: json['refreshBeforeExpiry'] as int? ?? 300,
    );
  }

  // ---------------------------------------------------------------------------
  // Equatable / Object
  // ---------------------------------------------------------------------------

  @override
  List<Object?> get props => [tokenLifetime, autoRefresh, refreshBeforeExpiry];

  @override
  String toString() =>
      'AuthConfig(tokenLifetime: ${tokenLifetime}s, autoRefresh: $autoRefresh, '
      'refreshBeforeExpiry: ${refreshBeforeExpiry}s)';
}
