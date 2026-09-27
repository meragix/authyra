import 'dart:async';

import 'package:authyra_flutter/authyra_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/demo/demo_auth_provider.dart';
import '../../core/demo/demo_rate_limit_callbacks.dart';

/// Thin wrapper around `Authyra.instance`: Authyra already owns the auth
/// state machine, this Cubit just republishes it to the widget tree and
/// translates sign-in calls into the demo provider's typed params.
class AuthCubit extends Cubit<AuthState> {
  final DemoRateLimitCallbacks callbacks;
  late final StreamSubscription<AuthState> _sub;

  AuthCubit({required this.callbacks}) : super(Authyra.instance.currentState) {
    _sub = Authyra.instance.authStateChanges.listen(emit);
  }

  Future<void> signInWithDemoAccount() => signIn(
        email: DemoAuthProvider.defaultEmail,
        password: DemoAuthProvider.demoPassword,
      );

  Future<void> signIn({required String email, required String password}) async {
    try {
      await Authyra.instance.signIn(
        'demo',
        params: CredentialsSignInParams(email: email, password: password),
      );
      callbacks.reset();
    } on AuthenticationFailedException {
      callbacks.recordFailedAttempt();
      rethrow;
    }
  }

  Future<void> signOut() => Authyra.instance.signOut();

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
