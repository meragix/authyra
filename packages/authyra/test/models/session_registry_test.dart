import 'package:test/test.dart';
import 'package:authyra/src/session/session_registry.dart';
import 'package:authyra/src/models/auth_session.dart';
import 'package:authyra/src/models/auth_user.dart';

AuthUser _user(String id) => AuthUser(id: id, email: '$id@test.com');

AuthSession _session(String userId, {bool expired = false}) {
  final now = DateTime.now();
  return AuthSession(
    providerId: 'credentials',
    user: _user(userId),
    accessToken: 'token_$userId',
    expiresAt: expired
        ? now.subtract(const Duration(hours: 1))
        : now.add(const Duration(hours: 1)),
    createdAt: now,
    lastUsedAt: now,
  );
}

void main() {
  group('SessionRegistry', () {
    test('empty registry has no active session', () {
      const registry = SessionRegistry();
      expect(registry.activeSession, isNull);
      expect(registry.hasActiveSession, isFalse);
      expect(registry.accountCount, 0);
      expect(registry.allUsers, isEmpty);
    });

    group('addSession', () {
      test('first added session becomes active by default', () {
        const registry = SessionRegistry();
        final s = _session('alice');
        final r = registry.addSession(s);

        expect(r.activeUserId, 'alice');
        expect(r.activeSession?.user.id, 'alice');
        expect(r.accountCount, 1);
      });

      test('second session added with setAsActive=false leaves first active', () {
        final r = const SessionRegistry()
            .addSession(_session('alice'))
            .addSession(_session('bob'), setAsActive: false);

        expect(r.activeUserId, 'alice');
        expect(r.accountCount, 2);
      });

      test('second session added with setAsActive=true replaces active', () {
        final r = const SessionRegistry()
            .addSession(_session('alice'))
            .addSession(_session('bob'));

        expect(r.activeUserId, 'bob');
        expect(r.accountCount, 2);
      });

      test('re-adding same userId replaces the session', () {
        final r = const SessionRegistry()
            .addSession(_session('alice'))
            .addSession(_session('alice'));

        expect(r.accountCount, 1);
      });

      test('original registry is not mutated', () {
        const original = SessionRegistry();
        final updated = original.addSession(_session('alice'));
        expect(original.accountCount, 0);
        expect(updated.accountCount, 1);
      });
    });

    group('removeSession', () {
      test('removes a non-active session without changing active', () {
        final r = const SessionRegistry()
            .addSession(_session('alice'))
            .addSession(_session('bob'), setAsActive: false);

        final r2 = r.removeSession('bob');
        expect(r2.accountCount, 1);
        expect(r2.activeUserId, 'alice');
      });

      test('removing active session auto-elects next most recent', () {
        final now = DateTime.now();
        final alice = AuthSession(
          providerId: 'credentials',
          user: _user('alice'),
          accessToken: 'tok_alice',
          expiresAt: now.add(const Duration(hours: 1)),
          createdAt: now,
          lastUsedAt: now.subtract(const Duration(minutes: 5)),
        );
        final bob = AuthSession(
          providerId: 'credentials',
          user: _user('bob'),
          accessToken: 'tok_bob',
          expiresAt: now.add(const Duration(hours: 1)),
          createdAt: now,
          lastUsedAt: now,
        );

        final r = const SessionRegistry()
            .addSession(alice)
            .addSession(bob);
        // bob is active (most recently added)
        final r2 = r.removeSession('bob');
        expect(r2.activeUserId, 'alice');
        expect(r2.accountCount, 1);
      });

      test('removing the only session leaves no active', () {
        final r = const SessionRegistry()
            .addSession(_session('alice'))
            .removeSession('alice');

        expect(r.activeUserId, isNull);
        expect(r.accountCount, 0);
      });

      test('removing unknown userId is a no-op', () {
        final r = const SessionRegistry()
            .addSession(_session('alice'))
            .removeSession('nobody');

        expect(r.accountCount, 1);
      });
    });

    group('switchTo', () {
      test('changes the active user', () {
        final r = const SessionRegistry()
            .addSession(_session('alice'))
            .addSession(_session('bob'), setAsActive: false);

        final r2 = r.switchTo('alice');
        expect(r2.activeUserId, 'alice');
      });

      test('unknown userId leaves registry unchanged', () {
        final r = const SessionRegistry().addSession(_session('alice'));
        final r2 = r.switchTo('nobody');
        // switchTo returns `this` when userId not found
        expect(r2.activeUserId, 'alice');
        expect(r2.accountCount, 1);
      });
    });

    group('updateSession', () {
      test('replaces the session for userId', () {
        final original = _session('alice');
        final updated = original.copyWith(accessToken: 'new_token');

        final r = const SessionRegistry()
            .addSession(original)
            .updateSession('alice', updated);

        expect(r.sessions['alice']?.accessToken, 'new_token');
      });

      test('no-op when userId not found', () {
        final r = const SessionRegistry()
            .addSession(_session('alice'))
            .updateSession('nobody', _session('nobody'));

        expect(r.accountCount, 1);
      });
    });

    group('removeExpiredSessions', () {
      test('removes expired sessions', () {
        final r = const SessionRegistry()
            .addSession(_session('alice'))
            .addSession(_session('bob', expired: true), setAsActive: false);

        final cleaned = r.removeExpiredSessions();
        expect(cleaned.accountCount, 1);
        expect(cleaned.sessions.containsKey('bob'), isFalse);
      });

      test('removing active expired session auto-elects valid one', () {
        final now = DateTime.now();
        final expiredBob = AuthSession(
          providerId: 'credentials',
          user: _user('bob'),
          accessToken: 'tok_bob',
          expiresAt: now.subtract(const Duration(hours: 1)),
          createdAt: now,
          lastUsedAt: now,
        );
        final r = const SessionRegistry()
            .addSession(_session('alice'), setAsActive: false)
            .addSession(expiredBob); // bob is active

        final cleaned = r.removeExpiredSessions();
        expect(cleaned.activeUserId, 'alice');
        expect(cleaned.accountCount, 1);
      });
    });

    group('clearAll', () {
      test('empties the registry', () {
        final r = const SessionRegistry()
            .addSession(_session('alice'))
            .addSession(_session('bob'))
            .clearAll();

        expect(r.accountCount, 0);
        expect(r.activeUserId, isNull);
      });
    });

    group('allSessions / allUsers', () {
      test('sorted by lastUsedAt descending', () {
        final now = DateTime.now();
        final alice = AuthSession(
          providerId: 'credentials',
          user: _user('alice'),
          accessToken: 'tok_alice',
          expiresAt: now.add(const Duration(hours: 1)),
          createdAt: now,
          lastUsedAt: now.subtract(const Duration(minutes: 10)),
        );
        final bob = AuthSession(
          providerId: 'credentials',
          user: _user('bob'),
          accessToken: 'tok_bob',
          expiresAt: now.add(const Duration(hours: 1)),
          createdAt: now,
          lastUsedAt: now,
        );

        final r = const SessionRegistry()
            .addSession(alice, setAsActive: false)
            .addSession(bob, setAsActive: false);

        expect(r.allUsers.first.id, 'bob');
        expect(r.allUsers.last.id, 'alice');
      });
    });

    group('serialisation', () {
      test('toJson / fromJson round-trip preserves all fields', () {
        final s = _session('alice');
        final r = const SessionRegistry().addSession(s);
        final restored = SessionRegistry.fromJson(r.toJson());

        expect(restored.accountCount, 1);
        expect(restored.activeUserId, 'alice');
        expect(restored.sessions['alice']?.accessToken, s.accessToken);
      });

      test('empty registry round-trip', () {
        const r = SessionRegistry();
        final restored = SessionRegistry.fromJson(r.toJson());
        expect(restored.accountCount, 0);
        expect(restored.activeUserId, isNull);
      });
    });

    group('Equatable', () {
      test('empty registry equals another empty registry', () {
        const r1 = SessionRegistry();
        const r2 = SessionRegistry();
        expect(r1, equals(r2));
      });

      test('registry with one session has correct account count and active user', () {
        final s = _session('alice');
        final r = const SessionRegistry().addSession(s);
        expect(r.accountCount, 1);
        expect(r.activeUserId, 'alice');
      });

      test('registries with different active users differ in activeUserId', () {
        final r1 = const SessionRegistry()
            .addSession(_session('alice'))
            .addSession(_session('bob'), setAsActive: false);
        final r2 = const SessionRegistry()
            .addSession(_session('alice'))
            .addSession(_session('bob'));
        // r1 active = alice, r2 active = bob (last added)
        expect(r1.activeUserId, 'alice');
        expect(r2.activeUserId, 'bob');
      });
    });
  });
}
