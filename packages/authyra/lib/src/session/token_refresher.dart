// TokenRefresher is planned for a future release.
//
// Intended responsibility: encapsulate the token refresh + retry policy
// that is currently inlined in AuthyraClient._tryAutoRefresh and
// AuthyraClient.refreshSession. Extracting it here will allow independent
// configuration of retry count, back-off strategy, and jitter per provider.
//
// Until then, refresh logic lives in:
//   packages/authyra/lib/src/client/authyra_client.dart
