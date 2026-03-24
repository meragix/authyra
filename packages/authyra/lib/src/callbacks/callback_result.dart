/// The outcome of an [AuthCallbacks] hook.
///
/// Every [AuthCallbacks] method returns a [CallbackResult]. Returning
/// [CallbackResult.deny] blocks the corresponding auth operation;
/// [CallbackResult.allow] lets it proceed.
///
/// ```dart
/// // Allow with optional attached data
/// return CallbackResult.allow({'role': 'admin'});
///
/// // Deny with a human-readable reason
/// return const CallbackResult.deny('IP address is blocked');
/// ```
///
/// See also:
/// - [AuthCallbacks], the interface that returns this type.
class CallbackResult {
  /// Whether the auth operation should proceed.
  final bool shouldContinue;

  /// Human-readable reason for a denial, or `null` when allowed.
  ///
  /// Surfaced as the message of the [AuthenticationFailedException] thrown
  /// by [AuthyraClient] when [isDenied] is `true`.
  final String? errorMessage;

  /// Arbitrary data attached to this result.
  ///
  /// Can be used to pass context from a hook back to the caller — for example,
  /// a [SessionMetadata] map populated in [AuthCallbacks.onBeforeSessionCreate].
  final Map<String, dynamic>? data;

  /// Creates an allow result, optionally carrying [data].
  ///
  /// ```dart
  /// return const CallbackResult.allow();
  /// return CallbackResult.allow({'enrichedRole': 'admin'});
  /// ```
  const CallbackResult.allow([this.data])
      : shouldContinue = true,
        errorMessage = null;

  /// Creates a deny result with a required [errorMessage] and optional [data].
  ///
  /// The [errorMessage] is forwarded to the [AuthenticationFailedException]
  /// that [AuthyraClient] throws when the hook returns this result.
  ///
  /// ```dart
  /// return const CallbackResult.deny('Account suspended');
  /// return CallbackResult.deny('Domain not allowed', {'domain': host});
  /// ```
  const CallbackResult.deny(this.errorMessage, [this.data])
      : shouldContinue = false;

  /// Whether the auth operation should proceed.
  bool get isAllowed => shouldContinue;

  /// Whether the auth operation was blocked by this result.
  ///
  /// When `true`, [errorMessage] is guaranteed to be non-null.
  bool get isDenied => !shouldContinue;
}
