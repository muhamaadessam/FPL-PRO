import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../storage/cache_helper.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(_initialThemeMode());

  void setThemeMode(ThemeMode mode) {
    emit(mode);
    CacheHelper.put(key: 'theme_mode', value: mode.name);
  }
}

ThemeMode _initialThemeMode() {
  final cached = CacheHelper.isInitialized
      ? CacheHelper.get(key: 'theme_mode')
      : null;
  if (cached is! String) return ThemeMode.system;
  return ThemeMode.values.firstWhere(
    (m) => m.name == cached,
    orElse: () => ThemeMode.system,
  );
}
