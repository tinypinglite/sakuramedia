class SessionSnapshot {
  const SessionSnapshot({
    required this.baseUrl,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  const SessionSnapshot.empty()
    : baseUrl = '',
      accessToken = '',
      refreshToken = '',
      expiresAt = null;

  final String baseUrl;
  final String accessToken;
  final String refreshToken;
  final DateTime? expiresAt;

  bool get hasBaseUrl => baseUrl.isNotEmpty;
  bool get hasAccessToken => accessToken.isNotEmpty;
  bool get hasRefreshToken => refreshToken.isNotEmpty;
  bool get hasSession => hasAccessToken && hasRefreshToken;

  SessionSnapshot copyWith({
    String? baseUrl,
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
  }) {
    return SessionSnapshot(
      baseUrl: baseUrl ?? this.baseUrl,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
    );
  }
}
