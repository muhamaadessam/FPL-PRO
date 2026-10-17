import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/storage/secure_storage_helper.dart';
import '../../domain/entities/official_session.dart';

class SessionStore {
  SessionStore([FlutterSecureStorage? storage])
    : _storage = SecureStorageHelper(storage);

  static const _key = 'official_fpl_session';
  // Kept after logout so the team ID field can be filled in next time.
  static const _lastEntryIdKey = 'last_fpl_entry_id';
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
    final entryId = session.entryId;
    if (entryId != null) {
      await _storage.put(key: _lastEntryIdKey, value: '$entryId');
    }
  }

  Future<int?> readLastEntryId() async {
    return int.tryParse(await _storage.get(key: _lastEntryIdKey) ?? '');
  }

  Future<void> clear() async {
    await _storage.remove(key: _key);
  }
}
