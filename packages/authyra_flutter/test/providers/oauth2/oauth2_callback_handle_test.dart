import 'package:authyra_flutter/src/providers/oauth2/oauth2_callback_handle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(OAuth2CallbackHandler.clearAll);

  group('OAuth2CallbackHandler', () {
    test('routes a callback to the handler registered under its state', () {
      Uri? received;
      OAuth2CallbackHandler.registerPendingState(
        'state-a',
        (uri) => received = uri,
      );

      OAuth2CallbackHandler.handleCallback(
        Uri.parse('myapp://callback?state=state-a&code=abc'),
      );

      expect(received, isNotNull);
      expect(received!.queryParameters['code'], 'abc');
    });

    test(
        'two providers sharing the same redirect scheme do not collide '
        '(the bug scheme-based routing had)', () {
      final receivedByProvider = <String, Uri>{};

      OAuth2CallbackHandler.registerPendingState(
        'state-discord',
        (uri) => receivedByProvider['discord'] = uri,
      );
      OAuth2CallbackHandler.registerPendingState(
        'state-slack',
        (uri) => receivedByProvider['slack'] = uri,
      );

      // Both providers use the exact same custom scheme "myapp".
      OAuth2CallbackHandler.handleCallback(
        Uri.parse('myapp://callback?state=state-slack&code=slack-code'),
      );
      OAuth2CallbackHandler.handleCallback(
        Uri.parse('myapp://callback?state=state-discord&code=discord-code'),
      );

      expect(
        receivedByProvider['slack']?.queryParameters['code'],
        'slack-code',
      );
      expect(
        receivedByProvider['discord']?.queryParameters['code'],
        'discord-code',
      );
    });

    test('falls back to the URI fragment for implicit-flow redirects', () {
      Uri? received;
      OAuth2CallbackHandler.registerPendingState(
        'state-implicit',
        (uri) => received = uri,
      );

      OAuth2CallbackHandler.handleCallback(
        Uri.parse('myapp://callback#state=state-implicit&access_token=xyz'),
      );

      expect(received, isNotNull);
    });

    test('ignores a callback with no state parameter', () {
      var callbackInvoked = false;
      OAuth2CallbackHandler.registerPendingState(
        'state-a',
        (uri) => callbackInvoked = true,
      );

      expect(
        () => OAuth2CallbackHandler.handleCallback(
          Uri.parse('myapp://callback?code=abc'),
        ),
        returnsNormally,
      );
      expect(callbackInvoked, isFalse);
    });

    test('ignores a callback for an unknown or already-resolved state', () {
      expect(
        () => OAuth2CallbackHandler.handleCallback(
          Uri.parse('myapp://callback?state=never-registered&code=abc'),
        ),
        returnsNormally,
      );
    });

    test('unregisterPendingState stops further routing for that state', () {
      var callbackInvoked = false;
      OAuth2CallbackHandler.registerPendingState(
        'state-a',
        (uri) => callbackInvoked = true,
      );

      OAuth2CallbackHandler.unregisterPendingState('state-a');
      OAuth2CallbackHandler.handleCallback(
        Uri.parse('myapp://callback?state=state-a&code=abc'),
      );

      expect(callbackInvoked, isFalse);
    });

    test('clearAll removes every pending registration', () {
      var callbackInvoked = false;
      OAuth2CallbackHandler.registerPendingState(
        'state-a',
        (uri) => callbackInvoked = true,
      );

      OAuth2CallbackHandler.clearAll();
      OAuth2CallbackHandler.handleCallback(
        Uri.parse('myapp://callback?state=state-a&code=abc'),
      );

      expect(callbackInvoked, isFalse);
    });
  });
}
