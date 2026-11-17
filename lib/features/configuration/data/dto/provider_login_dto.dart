import 'package:sakuramedia/core/json/json_parse.dart';

class ProviderLoginCookieSetPayload {
  const ProviderLoginCookieSetPayload({
    required this.url,
    required this.values,
  });

  final String url;
  final Map<String, String> values;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'url': url, 'values': values};
  }
}

class ProviderLoginLocalStorageSetPayload {
  const ProviderLoginLocalStorageSetPayload({
    required this.origin,
    required this.items,
  });

  final String origin;
  final Map<String, String> items;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'origin': origin, 'items': items};
  }
}

class ProviderLoginSessionDto {
  const ProviderLoginSessionDto({
    required this.id,
    required this.providerKey,
    required this.accountLabel,
    required this.expiresAt,
  });

  final String id;
  final String providerKey;
  final String? accountLabel;
  final DateTime? expiresAt;

  factory ProviderLoginSessionDto.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final providerKey = json['provider_key'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException(
        'provider_login_session.id must be a non-empty string',
      );
    }
    if (providerKey is! String || providerKey.trim().isEmpty) {
      throw const FormatException(
        'provider_login_session.provider_key must be a non-empty string',
      );
    }
    final accountLabel = json['account_label'];
    if (accountLabel != null && accountLabel is! String) {
      throw const FormatException(
        'provider_login_session.account_label must be a string or null',
      );
    }
    return ProviderLoginSessionDto(
      id: id,
      providerKey: providerKey,
      accountLabel: accountLabel as String?,
      expiresAt: asDateTime(json['expires_at']),
    );
  }
}
