import 'package:authyra_flutter/authyra_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            try {
              final user = await Authyra.instance.signIn('google');
              if (kDebugMode) {
                print('✅ Signed in: ${user.email}');
              }
            } catch (e) {
              if (kDebugMode) {
                print('❌ Error: $e');
              }
            }
          },
          child: const Text('Sign in with Google'),
        ),
      ),
    );
  }
}
