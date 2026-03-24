import 'package:test/test.dart';
import 'package:authyra/src/session/session_manager.dart';
import 'package:authyra/src/models/auth_session.dart';
import 'package:authyra/src/models/auth_user.dart';
import 'package:authyra/src/storage/memory_storage.dart';
import 'package:authyra/src/exceptions/auth_exceptions.dart';

AuthUser _user(String id) => AuthUser(id: id, email: '$id@test.com');

AuthSession _session(String userId, {bool expired = false}) {
  final now = DateTime.now();
  return AuthSession(
    providerId: 'credentials',
    user: _user(userId),
    accessToken: 'token_$userId',
    refreshToken: 'refresh_$userId',
    expiresAt: expired
        ? now.subtract(const Duration(hours: 1))
        : now.add(const Duration(hours: 1)),
    createdAt: now,
    lastUsedAt: now,
  );
}

void main() {
  group('SessionManager', () {
    late InMemoryStorage storage;
    late SessionManager manager;

    setUp(() async {
      storage = InMemoryStorage();
      manager = SessionManager(storage: storage);
      await manager.initialize();
    });

    tearDown(() async {
      await manager.dispose();
    });

    group('initialize', () {
      test('starts with empty registry on clean storage', () {
        expect(manager.accountCount, 0);
        expect(manager.activeSession, isNull);
      });

      test('restores persisted sessions on second init', () async {
        await manager.saveSession(_session('alice'));
        await manager.dispose();

        final manager2 = SessionManager(storage: storage);
        await manager2.initialize();

        expect(manager2.accountCount, 1);
        expect(manager2.activeSession?.user.id, 'alice');
        await manager2.dispose();
      });

      test('prunes expired sessions at startup', () async {
        await manager.saveSession(_session('alice'));
        // Manually write an expired session directly to storage to simulate
        // an already-persisted but expired session
        await manager.saveSession(_session('bob', expired: true), setAsActive: false);
        await manager.dispose();

        final manager2 = SessionManager(storage: storage);
        await manager2.initialize();

        expect(manager2.accountCount, 1);
        expect(manager2.sessions.containsKey('bob'), isFalse);
        await manager2.dispose();
      });
    });

    group('saveSession', () {
      test('saves and makes session active by default', () async {
        await manager.saveSession(_session('alice'));
        expect(manager.accountCount, 1);
        expect(manager.activeSession?.user.id, 'alice');
      });

      test('saves without setting active when setAsActive=false', () async {
        await manager.saveSession(_session('alice'));
        await manager.saveSession(_session('bob'), setAsActive: false);
        expect(manager.activeSession?.user.id, 'alice');
        expect(manager.accountCount, 2);
      });

      test('replacing same userId updates the session', () async {
        await manager.saveSession(_session('alice'));
        final updated = _session('alice').copyWith(accessToken: 'new_token');
        await manager.saveSession(updated);
        expect(manager.accountCount, 1);
        expect(manager.activeSession?.accessToken, 'new_token');
      });

      test('notifies listeners on save', () async {
        AuthSession? notified;
        manager.addListener((session) => notified = session);
        await manager.saveSession(_session('alice'));
        expect(notified?.user.id, 'alice');
      });

      test('session is persisted to storage', () async {
        await manager.saveSession(_session('alice'));
        final raw = await storage.read('authyra_session_registry');
        expect(raw, isNotNull);
        expect(raw, contains('alice'));
      });
    });

    group('getActiveSession', () {
      test('returns null when no active session', () async {
        expect(await manager.getActiveSession(), isNull);
      });

      test('returns active session when valid', () async {
        await manager.saveSession(_session('alice'));
        final session = await manager.getActiveSession();
        expect(session?.user.id, 'alice');
      });

      test('throws TokenExpiredException when active session is expired', () async {
        await manager.saveSession(_session('alice', expired: true));
        expect(
          () => manager.getActiveSession(),
          throwsA(isA<TokenExpiredException>()),
        );
      });
    });

    group('getSession', () {
      test('returns session for known userId', () async {
        await manager.saveSession(_session('alice'));
        final session = await manager.getSession('alice');
        expect(session?.user.id, 'alice');
      });

      test('returns null for unknown userId', () async {
        final session = await manager.getSession('ghost');
        expect(session, isNull);
      });
    });

    group('updateSession', () {
      test('updates an existing session', () async {
        await manager.saveSession(_session('alice'));
        final updated = _session('alice').copyWith(accessToken: 'updated_token');
        await manager.updateSession('alice', updated);
        expect(manager.activeSession?.accessToken, 'updated_token');
      });

      test('notifies listeners when active user is updated', () async {
        await manager.saveSession(_session('alice'));
        AuthSession? notified;
        manager.addListener((s) => notified = s);
        final updated = _session('alice').copyWith(accessToken: 'refreshed');
        await manager.updateSession('alice', updated);
        expect(notified?.accessToken, 'refreshed');
      });

      test('no-op for unknown userId', () async {
        await manager.saveSession(_session('alice'));
        await manager.updateSession('ghost', _session('ghost'));
        expect(manager.accountCount, 1);
      });
    });

    group('switchAccount', () {
      test('changes the active account', () async {
        await manager.saveSession(_session('alice'));
        await manager.saveSession(_session('bob'), setAsActive: false);
        await manager.switchAccount('alice');
        expect(manager.activeSession?.user.id, 'alice');
      });

      test('throws AccountNotFoundException for unknown userId', () async {
        expect(
          () => manager.switchAccount('ghost'),
          throwsA(isA<AccountNotFoundException>()),
        );
      });

      test('throws TokenExpiredException when switching to expired session', () async {
        await manager.saveSession(_session('alice'));
        await manager.saveSession(
          _session('bob', expired: true),
          setAsActive: false,
        );
        expect(
          () => manager.switchAccount('bob'),
          throwsA(isA<TokenExpiredException>()),
        );
      });
    });

    group('removeSession', () {
      test('removes a session', () async {
        await manager.saveSession(_session('alice'));
        await manager.saveSession(_session('bob'), setAsActive: false);
        await manager.removeSession('bob');
        expect(manager.accountCount, 1);
        expect(await manager.getSession('bob'), isNull);
      });

      test('removing active session switches to next account', () async {
        await manager.saveSession(_session('alice'), setAsActive: false);
        await manager.saveSession(_session('bob'));
        // bob is active
        await manager.removeSession('bob');
        expect(manager.activeSession?.user.id, 'alice');
      });

      test('no-op for unknown userId', () async {
        await manager.saveSession(_session('alice'));
        await manager.removeSession('ghost');
        expect(manager.accountCount, 1);
      });
    });

    group('clearActiveSession', () {
      test('removes the active session', () async {
        await manager.saveSession(_session('alice'));
        await manager.clearActiveSession();
        expect(manager.activeSession, isNull);
        expect(manager.accountCount, 0);
      });

      test('no-op when no active session', () async {
        await manager.clearActiveSession();
        expect(manager.accountCount, 0);
      });
    });

    group('clearAllSessions', () {
      test('removes all sessions', () async {
        await manager.saveSession(_session('alice'));
        await manager.saveSession(_session('bob'), setAsActive: false);
        await manager.clearAllSessions();
        expect(manager.accountCount, 0);
        expect(manager.activeSession, isNull);
      });

      test('notifies listeners with null', () async {
        await manager.saveSession(_session('alice'));
        AuthSession? notified = _session('sentinel');
        manager.addListener((s) => notified = s);
        await manager.clearAllSessions();
        expect(notified, isNull);
      });
    });

    group('cleanExpiredSessions', () {
      test('removes expired sessions and returns count', () async {
        await manager.saveSession(_session('alice'));
        await manager.saveSession(
          _session('bob', expired: true),
          setAsActive: false,
        );
        final removed = await manager.cleanExpiredSessions();
        expect(removed, 1);
        expect(manager.accountCount, 1);
      });

      test('returns 0 when no expired sessions', () async {
        await manager.saveSession(_session('alice'));
        final removed = await manager.cleanExpiredSessions();
        expect(removed, 0);
      });
    });

    group('getAccessToken', () {
      test('returns access token for active session', () async {
        await manager.saveSession(_session('alice'));
        final token = await manager.getAccessToken();
        expect(token, 'token_alice');
      });

      test('returns null when no active session', () async {
        final token = await manager.getAccessToken();
        expect(token, isNull);
      });

      test('returns token for specific user', () async {
        await manager.saveSession(_session('alice'));
        await manager.saveSession(_session('bob'), setAsActive: false);
        final token = await manager.getAccessTokenForUser('bob');
        expect(token, 'token_bob');
      });
    });

    group('listeners', () {
      test('addListener / removeListener', () async {
        int callCount = 0;
        void listener(AuthSession? _) => callCount++;

        manager.addListener(listener);
        await manager.saveSession(_session('alice'));
        expect(callCount, 1);

        manager.removeListener(listener);
        await manager.saveSession(_session('bob'), setAsActive: false);
        expect(callCount, 1); // no new call
      });
    });

    group('sessionStream', () {
      test('emits session on save', () async {
        final emitted = <AuthSession?>[];
        final sub = manager.sessionStream.listen(emitted.add);

        await manager.saveSession(_session('alice'));
        await Future.microtask(() {});

        sub.cancel();
        expect(emitted, isNotEmpty);
        expect(emitted.last?.user.id, 'alice');
      });
    });

    group('hasValidSession', () {
      test('returns true for valid session', () async {
        await manager.saveSession(_session('alice'));
        expect(await manager.hasValidSession('alice'), isTrue);
      });

      test('returns false for expired session', () async {
        await manager.saveSession(_session('alice', expired: true));
        expect(await manager.hasValidSession('alice'), isFalse);
      });

      test('returns false for unknown userId', () async {
        expect(await manager.hasValidSession('ghost'), isFalse);
      });
    });
  });
}

extension on SessionManager {
  Map<String, AuthSession> get sessions => getRegistry().sessions;
}
