import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Drives `ShadApp.themeMode`. Kept deliberately binary (light/dark only, no
/// "system" option) to match a simple on/off switch in the UI.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.light);

  bool get isDark => state == ThemeMode.dark;

  void toggle() => emit(isDark ? ThemeMode.light : ThemeMode.dark);

  void setDark(bool dark) => emit(dark ? ThemeMode.dark : ThemeMode.light);
}
