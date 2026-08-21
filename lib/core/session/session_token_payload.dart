import 'package:sakuramedia/core/network/api_error_dto.dart';
import 'package:sakuramedia/core/network/api_exception.dart';

/// The token fields that must be present before a session can be updated.
///
/// Other fields returned alongside tokens are intentionally parsed by the
/// feature DTO. Keeping this value object limited to the session credentials
/// makes it possible to validate the update atomically at the call site.
class SessionTokenPayload {
  const SessionTokenPayload({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  static const invalidResponseMessage = '认证响应格式错误';
  static const invalidResponseCode = 'invalid_auth_response';

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  static ApiException get invalidResponseException => _invalidResponse();

  factory SessionTokenPayload.fromJson(Map<String, dynamic> json) {
    final accessToken = _requiredToken(json['access_token']);
    final refreshToken = _requiredToken(json['refresh_token']);
    final expiresAt = _requiredExpiresAt(json['expires_at']);

    return SessionTokenPayload(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );
  }

  static String _requiredToken(dynamic value) {
    if (value is! String) {
      throw _invalidResponse();
    }
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw _invalidResponse();
    }
    return normalized;
  }

  static DateTime _requiredExpiresAt(dynamic value) {
    if (value is! String || value.trim().isEmpty) {
      throw _invalidResponse();
    }
    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) {
      throw _invalidResponse();
    }
    return parsed.toUtc();
  }

  static ApiException _invalidResponse() {
    return const ApiException(
      message: invalidResponseMessage,
      error: ApiErrorDto(
        code: invalidResponseCode,
        message: invalidResponseMessage,
      ),
    );
  }
}
