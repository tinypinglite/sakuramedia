class SessionSnapshot {
  const SessionSnapshot({
    required this.baseUrl,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String baseUrl;
  final String accessToken;
  final String refreshToken;
  final DateTime? expiresAt;

  bool get hasSession => accessToken.isNotEmpty && refreshToken.isNotEmpty;

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
