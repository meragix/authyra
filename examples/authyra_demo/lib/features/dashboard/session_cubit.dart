import 'dart:async';

import 'package:authyra_flutter/authyra_flutter.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SessionState extends Equatable {
  final AuthSession? session;
  final bool refreshing;

  const SessionState({this.session, this.refreshing = false});

  SessionState copyWith({AuthSession? session, bool? refreshing}) => SessionState(
        session: session ?? this.session,
        refreshing: refreshing ?? this.refreshing,
      );

  @override
  List<Object?> get props => [session, refreshing];
}

/// Mirrors `Authyra.instance.sessionStream` and adds a "force refresh" action
/// so the dashboard can demonstrate real background token refresh on demand
/// instead of waiting for the timer. The live "expires in" countdown is
/// handled by the page itself (a UI-only tick, not session data), so it isn't
/// swallowed by Cubit's equality-based emit deduplication.
class SessionCubit extends Cubit<SessionState> {
  late final StreamSubscription<AuthSession?> _sub;

  SessionCubit() : super(const SessionState()) {
    // Seed with the currently active session; the stream keeps it live from here.
    Authyra.instance.getSession().then((session) {
      if (!isClosed) emit(state.copyWith(session: session));
    });
    _sub = Authyra.instance.sessionStream.listen((session) {
      emit(state.copyWith(session: session));
    });
  }

  Future<void> forceRefresh() async {
    emit(state.copyWith(refreshing: true));
    await Authyra.instance.refreshSession();
    emit(state.copyWith(refreshing: false));
  }

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
