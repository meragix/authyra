import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:authyra_demo/features/auth/presentation/login_screen.dart';
import 'package:authyra_demo/features/home/presentation/home_screen.dart';
import 'package:authyra_flutter/authyra_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure logging (optional, but recommended for debugging)
  AuthyraLogger.configure(LoggerConfig());

  // Create an instance of the Google OAuth2 provider with your client ID. You can
  // create multiple providers for different services and pass them all to the client.
  final googleProvider = GoogleProvider(clientId: 'YOUR_CLIENT_ID');

  // Method 1 (direct constructor)
  final client = AuthyraClient(
    providers: [googleProvider],
    storage: SecureAuthStorage(),
    config: AuthConfig(autoRefresh: false),
  );

  // Method 2 (builder pattern)
  // final client = AuthyraClientBuilder()
  //     .addProvider(googleProvider)
  //     .setStorage(SecureAuthStorage())
  //     .setConfig(AuthConfig(autoRefresh: false))
  //     .build();

  // Initialize the client before running the app. This will restore any
  // existing session and ensure the client is ready to use when the app starts.
  await client.initialize();

  // Register the deep-link callback handler for the Google provider. The scheme
  // must match the redirect URI scheme you configured in the Google Cloud Console.
  final scheme = 'com.googleusercontent.apps.YOUR_GOOGLE_CLIENT_ID';
  OAuth2CallbackHandler.registerProvider(scheme, googleProvider);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  StreamSubscription? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Handle initial link (if app was closed)
    final initialUri = await _appLinks.getInitialAppLink();
    if (initialUri != null) {
      OAuth2CallbackHandler.handleCallback(initialUri);
    }

    // Handle links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        OAuth2CallbackHandler.handleCallback(uri);
      },
      onError: (err) {
        if (kDebugMode) {
          print('Deep link error: $err');
        }
      },
    );
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: StreamBuilder<AuthSession?>(
        stream: Authyra.instance.sessionStream,
        builder: (context, snapshot) {
          final session = snapshot.data;
          return session == null ? LoginScreen() : HomeScreen();
        },
      ),
    );
  }
}
