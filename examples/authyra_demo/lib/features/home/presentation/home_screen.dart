import 'package:authyra_flutter/authyra_flutter.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await Authyra.instance.signOut();
          },
          child: const Text('Sign Out'),
        ),
      ),
    );
  }
}
