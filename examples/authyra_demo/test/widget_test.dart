import 'package:authyra_demo/app.dart';
import 'package:authyra_demo/core/demo/authyra_bootstrap.dart';
import 'package:authyra_flutter/authyra_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() async {
    if (Authyra.isInitialized) {
      await Authyra.instance.dispose();
    }
  });

  testWidgets('shows the login page, then the dashboard after demo sign-in', (tester) async {
    final bootstrap = await AuthyraBootstrap.build(storage: InMemoryStorage());
    await tester.pumpWidget(AuthyraDemoApp(bootstrap: bootstrap));
    await tester.pumpAndSettle();

    expect(find.text('Continue with demo account'), findsOneWidget);

    // The dashboard has a live 1s countdown ticker once mounted, so
    // pumpAndSettle() would never converge here: pump a bounded number of
    // frames instead, enough to cover the demo provider's fake network delay.
    await tester.tap(find.text('Continue with demo account'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    // "Dashboard" itself appears twice (page heading + bottom nav label),
    // so assert on the page's unique subtitle instead.
    expect(
      find.text('This is the live state Authyra is holding for the active account.'),
      findsOneWidget,
    );
    expect(find.text('Continue with demo account'), findsNothing);

    // SessionManager's background TokenRefresher started a periodic timer on
    // sign-in; stop it explicitly before the test ends rather than relying
    // solely on tearDown, the widget-tree-disposal check runs first.
    await Authyra.instance.dispose();
  });
}
