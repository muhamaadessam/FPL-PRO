import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fantasy_pl/core/storage/cache_helper.dart';

void main() {
  test('stores and removes primitive preferences', () async {
    SharedPreferences.setMockInitialValues({});
    await CacheHelper.init();

    expect(await CacheHelper.put(key: 'theme', value: 'dark'), isTrue);
    expect(CacheHelper.get(key: 'theme'), 'dark');

    expect(await CacheHelper.put(key: 'compactMode', value: true), isTrue);
    expect(CacheHelper.get(key: 'compactMode'), isTrue);

    expect(await CacheHelper.remove(key: 'theme'), isTrue);
    expect(CacheHelper.get(key: 'theme'), isNull);
  });
}
