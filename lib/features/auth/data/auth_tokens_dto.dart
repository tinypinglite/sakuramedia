import 'package:sakuramedia/core/session/session_token_payload.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

class AuthUserDto {
  const AuthUserDto({required this.username, this.language});

  final String username;
  final String? language;

  factory AuthUserDto.fromJson(Map<String, dynamic> json) {
    return AuthUserDto(
      username: json['username'] as String? ?? '',
      language: json['language'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'username': username,
      if (language != null) 'language': language,
    };
  }
}

class AuthTokensDto {
  const AuthTokensDto({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.expiresAt,
    required this.refreshExpiresAt,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final DateTime expiresAt;
  final DateTime refreshExpiresAt;
  final AuthUserDto user;

  factory AuthTokensDto.fromJson(
    Map<String, dynamic> json, {
    AppLocalizations? l10n,
  }) {
    final tokenPayload = SessionTokenPayload.fromJson(json, l10n: l10n);
    return AuthTokensDto(
      accessToken: tokenPayload.accessToken,
      refreshToken: tokenPayload.refreshToken,
      tokenType: json['token_type'] as String? ?? 'Bearer',
      expiresIn: json['expires_in'] as int? ?? 0,
      expiresAt: tokenPayload.expiresAt,
      refreshExpiresAt:
          DateTime.tryParse(json['refresh_expires_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      user: AuthUserDto.fromJson(_asJsonMap(json['user'])),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': tokenType,
      'expires_in': expiresIn,
      'expires_at': expiresAt.toUtc().toIso8601String(),
      'refresh_expires_at': refreshExpiresAt.toUtc().toIso8601String(),
      'user': user.toJson(),
    };
  }

  static Map<String, dynamic> _asJsonMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic data) => MapEntry(key.toString(), data),
      );
    }
    return const <String, dynamic>{};
  }
}
