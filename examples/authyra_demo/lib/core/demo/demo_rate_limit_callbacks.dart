import 'package:authyra_flutter/authyra_flutter.dart';

/// Demonstrates the one Authyra mechanism that can actually block an
/// operation: `AuthCallbacks`. After [maxAttempts] failed sign-ins it denies
/// every further attempt until [reset] is called (on a successful sign-in).
///
/// A plugin could log this happening, but it could never cause it: only a
/// callback returning `CallbackResult.deny` stops the sign-in before the
/// provider runs. See the Playground tab.
class DemoRateLimitCallbacks extends AuthCallbacks {
  final int maxAttempts;
  final void Function(String message)? onBlocked;

  int _failedAttempts = 0;

  DemoRateLimitCallbacks({this.maxAttempts = 3, this.onBlocked});

  int get failedAttempts => _failedAttempts;
  bool get isBlocked => _failedAttempts >= maxAttempts;

  @override
  Future<CallbackResult> onBeforeSignIn(
    String providerName,
    AuthSignInParams? params,
  ) async {
    if (isBlocked) {
      final message =
          'Blocked after $maxAttempts failed attempts. Sign in with the '
          'correct password to reset the counter.';
      onBlocked?.call(message);
      return CallbackResult.deny(message);
    }
    return const CallbackResult.allow();
  }

  /// Call after a sign-in attempt fails for a reason other than this
  /// callback's own denial (a wrong password, typically).
  void recordFailedAttempt() {
    if (isBlocked) return;
    _failedAttempts++;
  }

  void reset() => _failedAttempts = 0;
}
