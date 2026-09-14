class OfficialSession {
  const OfficialSession({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.entryId,
    this.cookieHeader,
    this.csrfToken,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final int? entryId;
  final String? cookieHeader;
  final String? csrfToken;

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
    if (cookieHeader != null) 'cookieHeader': cookieHeader,
    if (csrfToken != null) 'csrfToken': csrfToken,
  };

  factory OfficialSession.fromJson(Map<String, dynamic> json) {
    return OfficialSession(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String?,
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
      entryId: _readInt(json['entryId']),
      cookieHeader: json['cookieHeader'] as String?,
      csrfToken: json['csrfToken'] as String?,
    );
  }

  OfficialSession copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    int? entryId,
    String? cookieHeader,
    String? csrfToken,
  }) {
    return OfficialSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      entryId: entryId ?? this.entryId,
      cookieHeader: cookieHeader ?? this.cookieHeader,
      csrfToken: csrfToken ?? this.csrfToken,
    );
  }
}

int? _readInt(dynamic value) => value is int ? value : int.tryParse('$value');
