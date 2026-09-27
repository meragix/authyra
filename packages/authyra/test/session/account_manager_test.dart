import 'package:test/test.dart';
import 'package:authyra/src/callbacks/auth_callbacks.dart';
import 'package:authyra/src/callbacks/callback_result.dart';
import 'package:authyra/src/events/auth_event_bus.dart';
import 'package:authyra/src/events/auth_events.dart';
import 'package:authyra/src/exceptions/auth_exceptions.dart';
import 'package:authyra/src/models/auth_account.dart';
import 'package:authyra/src/models/auth_session.dart';
import 'package:authyra/src/models/auth_state.dart';
import 'package:authyra/src/models/auth_user.dart';
import 'package:authyra/src/session/account_manager.dart';
import 'package:authyra/src/session/session_manager.dart';
import 'package:authyra/src/storage/memory_storage.dart';

AuthSession _session(String userId) {
  final now = DateTime.now();
  final account = AuthAccount(
    id: 'credentials_$userId',
    userId: userId,
    providerId: 'credentials',
    providerAccountId: userId,
    accessToken: 'token_$userId',
    refreshToken: 'refresh_$userId',
    tokenExpiresAt: now.add(const Duration(hours: 1)),
  );
  return AuthSession(
    user: AuthUser(id: userId, email: '$userId@test.com'),
    activeAccountId: account.id,
    linkedAccounts: [account],
    createdAt: now,
    lastUsedAt: now,
  );
}

class _DenyingCallbacks extends AuthCallbacks {
  final bool denySwitch;
  final bool denyRemove;

  _DenyingCallbacks({this.denySwitch = false, this.denyRemove = false});

  @override
  Future<CallbackResult> onBeforeAccountSwitch(
    AuthUser fromUser,
    String toUserId,
  ) async {
    return denySwitch
        ? const CallbackResult.deny('switch denied')
        : const CallbackResult.allow();
  }

  @override
  Future<CallbackResult> onBeforeAccountRemove(AuthUser user) async {
    return denyRemove
        ? const CallbackResult.deny('remove denied')
        : const CallbackResult.allow();
  }
}

void main() {
  group('AccountManager', () {
    late SessionManager sessionManager;
    late AuthState? lastState;

    setUp(() async {
      sessionManager = SessionManager(storage: InMemoryStorage());
      await sessionManager.initialize();
      await sessionManager.saveSession(_session('alice'));
      await sessionManager.saveSession(_session('bob'), setAsActive: false);
      lastState = null;
    });

    tearDown(() => sessionManager.dispose());

    AccountManager manager({AuthCallbacks? callbacks, AuthEventBus? eventBus}) {
      return AccountManager(
        sessionManager: sessionManager,
        onStateChange: (s) => lastState = s,
        callbacks: callbacks,
        eventBus: eventBus,
      );
    }

    group('switchTo', () {
      test('switches and emits AccountSwitchEvent', () async {
        final bus = AuthEventBus();
        AccountSwitchEvent? captured;
        bus.on<AccountSwitchEvent>((e) => captured = e);

        await manager(eventBus: bus).switchTo('bob');

        expect(sessionManager.activeUser?.id, 'bob');
        expect(captured, isNotNull);
        expect(captured!.fromUser.id, 'alice');
        expect(captured!.toUser.id, 'bob');
        expect(lastState?.isAuthenticated, isTrue);
      });

      test('honours onBeforeAccountSwitch denial', () async {
        final callbacks = _DenyingCallbacks(denySwitch: true);

        expect(
          () => manager(callbacks: callbacks).switchTo('bob'),
          throwsA(isA<AuthenticationFailedException>()),
        );
        expect(sessionManager.activeUser?.id, 'alice');
      });

      test('allowing callback still switches', () async {
        final callbacks = _DenyingCallbacks(denySwitch: false);
        await manager(callbacks: callbacks).switchTo('bob');
        expect(sessionManager.activeUser?.id, 'bob');
      });
    });

    group('signOut', () {
      test('removes account and emits AccountRemovedEvent', () async {
        final bus = AuthEventBus();
        AccountRemovedEvent? captured;
        bus.on<AccountRemovedEvent>((e) => captured = e);

        await manager(eventBus: bus).signOut('bob');

        expect(sessionManager.accountCount, 1);
        expect(captured, isNotNull);
        expect(captured!.userId, 'bob');
      });

      test('honours onBeforeAccountRemove denial', () async {
        final callbacks = _DenyingCallbacks(denyRemove: true);

        expect(
          () => manager(callbacks: callbacks).signOut('bob'),
          throwsA(isA<AuthenticationFailedException>()),
        );
        expect(sessionManager.accountCount, 2);
      });

      test('unknown userId is a no-op and skips the callback', () async {
        final callbacks = _DenyingCallbacks(denyRemove: true);
        await manager(callbacks: callbacks).signOut('unknown');
        expect(sessionManager.accountCount, 2);
      });
    });
  });
}
