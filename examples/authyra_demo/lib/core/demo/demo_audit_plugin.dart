import 'package:authyra_flutter/authyra_flutter.dart';

/// Demonstrates the other side of the distinction shown in the Playground
/// tab: a plugin observes, it cannot block anything. A hook that throws is
/// caught and logged internally by AuthyraClient, never propagated, so this
/// class never has the power `DemoRateLimitCallbacks` has.
class DemoAuditPlugin extends AuthyraPlugin {
  final void Function(String message) onAudit;

  DemoAuditPlugin(this.onAudit);

  @override
  String get name => 'demo-audit';

  @override
  void install(AuthyraClient client) {
    onAudit('installed, watching sign-in/session lifecycle');
  }

  @override
  Future<void> onBeforeSignIn(String providerId, AuthSignInParams? params) async {
    onAudit('onBeforeSignIn("$providerId"), observed only, cannot block');
  }

  @override
  Future<void> onAfterSignIn(AuthSession session) async {
    onAudit('onAfterSignIn(${session.user.id})');
  }

  @override
  Future<void> onSessionExpired(AuthSession session) async {
    onAudit('onSessionExpired(${session.user.id})');
  }
}
