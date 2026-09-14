import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../storage/secure_storage_helper.dart';

class OfficialSession {
  const OfficialSession({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.entryId,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final int? entryId;

  bool get isExpired {
    final expiry = expiresAt;
    return accessToken.isEmpty ||
        expiry == null ||
        DateTime.now().isAfter(expiry.subtract(const Duration(seconds: 30)));
  }

  Map<String, String> get requestHeaders => {
    if (accessToken.isNotEmpty) 'X-API-Authorization': 'Bearer $accessToken',
  };

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    if (refreshToken != null) 'refreshToken': refreshToken,
    if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
    if (entryId != null) 'entryId': entryId,
  };

  factory OfficialSession.fromJson(Map<String, dynamic> json) {
    return OfficialSession(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String?,
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
      entryId: _readInt(json['entryId']),
    );
  }

  OfficialSession copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    int? entryId,
  }) {
    return OfficialSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      entryId: entryId ?? this.entryId,
    );
  }
}

int? _readInt(dynamic value) => value is int ? value : int.tryParse('$value');

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
