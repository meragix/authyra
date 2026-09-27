import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AppTheme {
  AppTheme._();

  static ShadThemeData light = ShadThemeData(
    brightness: Brightness.light,
    colorScheme: const ShadZincColorScheme.light(),
  );

  static ShadThemeData dark = ShadThemeData(
    brightness: Brightness.dark,
    colorScheme: const ShadZincColorScheme.dark(),
  );
}
