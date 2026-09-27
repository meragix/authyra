import 'package:authyra_flutter/src/providers/oauth2/pending_redirect_flow.dart';
import 'package:flutter_test/flutter_test.dart';

class _Flow with PendingRedirectFlow<String> {}

class _CancelledError implements Exception {
  final String reason;
  const _CancelledError(this.reason);

  @override
  String toString() => 'CancelledError($reason)';
}

void main() {
  group('PendingRedirectFlow', () {
    test('resolves with the value passed to resolveRedirect', () async {
      final flow = _Flow();

      final future = flow.awaitRedirect(
        launch: () async => flow.resolveRedirect('callback-value'),
        timeout: const Duration(seconds: 1),
        buildCancelledError: () => const _CancelledError('timeout'),
      );

      expect(await future, 'callback-value');
      expect(flow.hasPendingRedirect, isFalse);
    });

    test('hasPendingRedirect is true only while a flow is in flight', () async {
      final flow = _Flow();
      expect(flow.hasPendingRedirect, isFalse);

      final future = flow.awaitRedirect(
        launch: () async {
          expect(flow.hasPendingRedirect, isTrue);
        },
        timeout: const Duration(milliseconds: 200),
        buildCancelledError: () => const _CancelledError('timeout'),
      );

      await expectLater(future, throwsA(isA<_CancelledError>()));

      // A timeout settles the returned future but, like the original
      // per-provider implementations, does not clear internal state on its
      // own; the caller's `finally` block does that via cleanupRedirect().
      expect(flow.hasPendingRedirect, isTrue);
      flow.cleanupRedirect();
      expect(flow.hasPendingRedirect, isFalse);
    });

    test('times out and throws buildCancelledError() when never resolved',
        () async {
      final flow = _Flow();

      final future = flow.awaitRedirect(
        launch: () async {},
        timeout: const Duration(milliseconds: 50),
        buildCancelledError: () => const _CancelledError('timeout'),
      );

      await expectLater(
        future,
        throwsA(isA<_CancelledError>()
            .having((e) => e.reason, 'reason', 'timeout')),
      );
    });

    test('starting a new flow cancels a previous unresolved one', () async {
      final flow = _Flow();

      final first = flow.awaitRedirect(
        launch: () async {},
        timeout: const Duration(seconds: 5),
        buildCancelledError: () => const _CancelledError('cancelled'),
      );

      final second = flow.awaitRedirect(
        launch: () async => flow.resolveRedirect('second-value'),
        timeout: const Duration(seconds: 1),
        buildCancelledError: () => const _CancelledError('timeout'),
      );

      await expectLater(first, throwsA(isA<_CancelledError>()));
      expect(await second, 'second-value');
    });

    test('resolveRedirect is a no-op when nothing is pending', () {
      final flow = _Flow();
      expect(() => flow.resolveRedirect('stray'), returnsNormally);
      expect(flow.hasPendingRedirect, isFalse);
    });

    test('resolveRedirect after resolution is ignored, not a crash', () async {
      final flow = _Flow();

      final future = flow.awaitRedirect(
        launch: () async => flow.resolveRedirect('first'),
        timeout: const Duration(seconds: 1),
        buildCancelledError: () => const _CancelledError('timeout'),
      );

      expect(await future, 'first');
      // A duplicate deep link arriving after resolution must not throw.
      expect(() => flow.resolveRedirect('duplicate'), returnsNormally);
    });

    test('rethrows launch() failures and clears pending state', () async {
      final flow = _Flow();

      final future = flow.awaitRedirect(
        launch: () async => throw StateError('launch failed'),
        timeout: const Duration(seconds: 1),
        buildCancelledError: () => const _CancelledError('timeout'),
      );

      await expectLater(future, throwsA(isA<StateError>()));
      expect(flow.hasPendingRedirect, isFalse);
    });

    test(
        'cleanupRedirect detaches tracking but does not force the '
        'underlying future to settle', () async {
      final flow = _Flow();

      final future = flow.awaitRedirect(
        launch: () async {},
        timeout: const Duration(milliseconds: 50),
        buildCancelledError: () => const _CancelledError('cancelled'),
      );

      flow.cleanupRedirect();
      expect(flow.hasPendingRedirect, isFalse);

      // resolveRedirect after cleanup is a no-op (matching a real provider's
      // finally-block ordering); the original future still settles on its
      // own via the timeout.
      flow.resolveRedirect('too-late');
      await expectLater(future, throwsA(isA<_CancelledError>()));
    });
  });
}
