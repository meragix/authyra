import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../theme/theme_cubit.dart';

/// Sun/moon switch bound to [ThemeCubit]. Drop it anywhere, it reads and
/// writes the single shared theme state.
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, mode) {
        final isDark = mode == ThemeMode.dark;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDark ? LucideIcons.moon : LucideIcons.sun,
              size: 16,
              color: theme.colorScheme.foreground,
            ),
            const SizedBox(width: 8),
            ShadSwitch(
              value: isDark,
              onChanged: (value) => context.read<ThemeCubit>().setDark(value),
            ),
          ],
        );
      },
    );
  }
}
