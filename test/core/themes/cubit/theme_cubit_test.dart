import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fantasy_pl/core/storage/cache_helper.dart';
import 'package:fantasy_pl/core/themes/cubit/theme_cubit.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CacheHelper.init();
  });

  test('ThemeCubit defaults to system and persists preference', () async {
    final cubit = ThemeCubit();
    expect(cubit.state, ThemeMode.system);

    cubit.setThemeMode(ThemeMode.light);
    expect(cubit.state, ThemeMode.light);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'light');

    final cubit2 = ThemeCubit();
    expect(cubit2.state, ThemeMode.light);
  });
}
