import 'dart:async';

import 'package:authyra_flutter/authyra_flutter.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AccountsState extends Equatable {
  final List<AuthSession> sessions;
  final String? activeUserId;

  const AccountsState({this.sessions = const [], this.activeUserId});

  @override
  List<Object?> get props => [sessions, activeUserId];
}

/// Wraps `Authyra.instance.accounts` (`AccountManager`). "Add account"
/// signs in a *new, distinct* identity via the demo provider, this is
/// multi-account (several separate sessions switchable side by side), not
/// account-linking: Authyra doesn't merge them into one identity, and
/// neither does this demo.
class AccountsCubit extends Cubit<AccountsState> {
  int _demoAccountCount = 0;
  late final StreamSubscription<AuthSession?> _sub;

  AccountsCubit() : super(const AccountsState()) {
    _sub = Authyra.instance.sessionStream.listen((_) => refresh());
    refresh();
  }

  Future<void> refresh() async {
    final sessions = await Authyra.instance.accounts.getAllSessions();
    emit(AccountsState(sessions: sessions, activeUserId: Authyra.instance.currentUser?.id));
  }

  Future<void> addDemoAccount() async {
    _demoAccountCount++;
    final email = 'demo+$_demoAccountCount@authyra.dev';
    await Authyra.instance.signIn(
      'demo',
      params: CredentialsSignInParams(email: email, password: 'demo'),
    );
    await refresh();
  }

  Future<void> switchTo(String userId) async {
    await Authyra.instance.accounts.switchTo(userId);
    await refresh();
  }

  Future<void> signOut(String userId) async {
    await Authyra.instance.accounts.signOut(userId);
    await refresh();
  }

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
