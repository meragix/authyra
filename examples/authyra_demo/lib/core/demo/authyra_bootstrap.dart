import 'package:authyra_flutter/authyra_flutter.dart';

import 'demo_audit_plugin.dart';
import 'demo_auth_provider.dart';
import 'demo_rate_limit_callbacks.dart';
import 'event_log_cubit.dart';

/// Everything the app needs to talk to Authyra, built once at startup and
/// handed down via [BlocProvider.value] in `app.dart`.
class AuthyraBootstrap {
  final AuthyraClient client;
  final DemoAuthProvider provider;
  final DemoRateLimitCallbacks callbacks;
  final EventLogCubit eventLog;

  AuthyraBootstrap._({
    required this.client,
    required this.provider,
    required this.callbacks,
    required this.eventLog,
  });

  /// [storage] defaults to [SecureAuthStorage] for real app runs. Tests
  /// should pass [InMemoryStorage] instead: [SecureAuthStorage] talks to a
  /// platform channel (Keychain/Keystore) that isn't available under plain
  /// `flutter test`.
  static Future<AuthyraBootstrap> build({AuthStorage? storage}) async {
    final eventLog = EventLogCubit();

    final callbacks = DemoRateLimitCallbacks(
      onBlocked: (message) => eventLog.add(EventLogSource.callback, message),
    );

    final plugin = DemoAuditPlugin(
      (message) => eventLog.add(EventLogSource.plugin, message),
    );

    final provider = DemoAuthProvider();

    final client = AuthyraClient(
      providers: [provider],
      storage: storage ?? SecureAuthStorage(),
      callbacks: callbacks,
      plugins: [plugin],
      config: const AuthConfig(
        autoRefresh: true,
        refreshBeforeExpiry: 30, // token lifetime is 60s, so this fires with margin to spare
      ),
    );

    await Authyra.initialize(client: client);

    client.events.stream.listen((event) {
      eventLog.add(EventLogSource.authEvent, _describe(event));
    });

    return AuthyraBootstrap._(
      client: client,
      provider: provider,
      callbacks: callbacks,
      eventLog: eventLog,
    );
  }

  static String _describe(AuthEvent event) {
    final json = Map<String, dynamic>.from(event.toJson());
    final type = json.remove('event') ?? event.runtimeType.toString();
    json.remove('timestamp');
    final rest = json.entries.map((e) => '${e.key}=${e.value}').join(', ');
    return rest.isEmpty ? '$type' : '$type ($rest)';
  }
}
