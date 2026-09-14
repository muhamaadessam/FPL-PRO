import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/storage/secure_storage_helper.dart';
import '../../domain/entities/official_session.dart';

class SessionStore {
  SessionStore([FlutterSecureStorage? storage])
    : _storage = SecureStorageHelper(storage);

  static const _key = 'official_fpl_session';
  final SecureStorageHelper _storage;

  Future<OfficialSession?> read() async {
    final value = await _storage.get(key: _key);
    if (value == null || value.isEmpty) return null;
    try {
      return OfficialSession.fromJson(
        jsonDecode(value) as Map<String, dynamic>,
      );
    } on Object {
      await clear();
      return null;
    }
  }

  Future<void> write(OfficialSession session) async {
    await _storage.put(key: _key, value: jsonEncode(session.toJson()));
  }

  Future<void> clear() async {
    await _storage.remove(key: _key);
  }
}
