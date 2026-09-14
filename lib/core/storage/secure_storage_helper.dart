import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageHelper {
  SecureStorageHelper([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<bool> put({required String key, required String value}) async {
    await _storage.write(key: key, value: value);
    return true;
  }

  Future<String?> get({required String key}) => _storage.read(key: key);

  Future<bool> remove({required String key}) async {
    await _storage.delete(key: key);
    return true;
  }

  Future<bool> clearData() async {
    await _storage.deleteAll();
    return true;
  }
}
