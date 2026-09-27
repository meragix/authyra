import 'package:flutter/material.dart';

import '../core/widgets/theme_toggle.dart';
import '../features/accounts/accounts_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/events/events_page.dart';
import '../features/playground/playground_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = [
    DashboardPage(),
    AccountsPage(),
    EventsPage(),
    PlaygroundPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Authyra Demo',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const ThemeToggle(),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(index: _index, children: _pages),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            label: 'Accounts',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            label: 'Playground',
          ),
        ],
      ),
    );
  }
}
