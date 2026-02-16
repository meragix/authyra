// Optional configuration for AuthyraClient
class AuthConfig {
  /// Token lifetime in seconds
  final int tokenLifetime;

  /// Auto-refresh token before expiration
  final bool autoRefresh;

  /// Delay before expiration to trigger the refresh (in seconds)
  final int refreshBeforeExpiry;

  const AuthConfig({
    this.tokenLifetime = 3600, // 1 hour by default
    this.autoRefresh = true,
    this.refreshBeforeExpiry = 300, // 5 minutes before
  });
}
