import 'package:flutter/widgets.dart';

import 'app.dart';
import 'core/demo/authyra_bootstrap.dart';

// This demo only wires DemoAuthProvider so it runs with zero configuration,
// no OAuth client ID, no backend. To add a real provider alongside it:
//   1. Add app_links to pubspec.yaml.
//   2. Build a GoogleProvider/OAuth2Provider (see docs: /providers/google,
//      /guides/oauth2-flow) and add it to AuthyraBootstrap's providers list.
//   3. Wire OAuth2CallbackHandler + AppLinks().uriLinkStream in main(),
//      before Authyra.initialize() (see docs: /guides/deep-links).

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bootstrap = await AuthyraBootstrap.build();

  runApp(AuthyraDemoApp(bootstrap: bootstrap));
}
