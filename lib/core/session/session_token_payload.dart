import 'package:sakuramedia/core/network/api_error_dto.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';

/// 认证链路没有 BuildContext；语言包缺失时回退默认语言（中文）。
final AppLocalizations _zhFallback = AppLocalizationsZh();

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

  /// 认证响应缺字段时的兜底文案。
  ///
  /// 语言包由调用方提供（provider 层走 appLocalizationsProvider）；缺失时回退
  /// 默认语言文案。
  static String invalidResponseMessage({AppLocalizations? l10n}) =>
      (l10n ?? _zhFallback).coreSessionInvalidAuthResponse;

  static const invalidResponseCode = 'invalid_auth_response';

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  static ApiException invalidResponseException({AppLocalizations? l10n}) =>
      _invalidResponse(l10n);

  factory SessionTokenPayload.fromJson(
    Map<String, dynamic> json, {
    AppLocalizations? l10n,
  }) {
    final accessToken = _requiredToken(json['access_token'], l10n);
    final refreshToken = _requiredToken(json['refresh_token'], l10n);
    final expiresAt = _requiredExpiresAt(json['expires_at'], l10n);

    return SessionTokenPayload(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );
  }

  static String _requiredToken(dynamic value, AppLocalizations? l10n) {
    if (value is! String) {
      throw _invalidResponse(l10n);
    }
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw _invalidResponse(l10n);
    }
    return normalized;
  }

  static DateTime _requiredExpiresAt(dynamic value, AppLocalizations? l10n) {
    if (value is! String || value.trim().isEmpty) {
      throw _invalidResponse(l10n);
    }
    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) {
      throw _invalidResponse(l10n);
    }
    return parsed.toUtc();
  }

  static ApiException _invalidResponse(AppLocalizations? l10n) {
    final message = invalidResponseMessage(l10n: l10n);
    return ApiException(
      message: message,
      error: ApiErrorDto(code: invalidResponseCode, message: message),
    );
  }
}
