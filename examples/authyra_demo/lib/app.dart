import 'package:authyra_flutter/authyra_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'core/demo/authyra_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'features/accounts/accounts_cubit.dart';
import 'features/auth/auth_cubit.dart';
import 'features/auth/login_page.dart';
import 'features/dashboard/session_cubit.dart';
import 'shell/home_shell.dart';

class AuthyraDemoApp extends StatelessWidget {
  final AuthyraBootstrap bootstrap;

  const AuthyraDemoApp({super.key, required this.bootstrap});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthCubit(callbacks: bootstrap.callbacks)),
        BlocProvider.value(value: bootstrap.eventLog),
        BlocProvider(create: (_) => ThemeCubit()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, mode) {
          return ShadApp(
            title: 'Authyra Demo',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: mode,
            home: BlocBuilder<AuthCubit, AuthState>(
              builder: (context, state) {
                if (!state.isAuthenticated) return const LoginPage();

                // Session-scoped Cubits: only meaningful once someone is signed in.
                return MultiBlocProvider(
                  key: ValueKey(state.user!.id),
                  providers: [
                    BlocProvider(create: (_) => SessionCubit()),
                    BlocProvider(create: (_) => AccountsCubit()),
                  ],
                  child: const HomeShell(),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
