import 'package:shared_preferences/shared_preferences.dart';

class CacheHelper {
  CacheHelper._();

  static SharedPreferences? _preferences;

  static Future<void> init() async {
    _preferences = await SharedPreferences.getInstance();
  }

  static bool get isInitialized => _preferences != null;

  static SharedPreferences get _instance {
    final preferences = _preferences;
    if (preferences == null) {
      throw StateError('Call CacheHelper.init() before using the cache.');
    }
    return preferences;
  }

  static Future<bool> put({required String key, required Object? value}) {
    if (value == null) return remove(key: key);
    if (value is String) return _instance.setString(key, value);
    if (value is bool) return _instance.setBool(key, value);
    if (value is int) return _instance.setInt(key, value);
    if (value is double) return _instance.setDouble(key, value);

    throw ArgumentError.value(
      value,
      'value',
      'Only String, bool, int, double, or null are supported.',
    );
  }

  static Object? get({required String key}) => _instance.get(key);

  static Future<bool> remove({required String key}) => _instance.remove(key);

  static Future<bool> clearData() => _instance.clear();
}
