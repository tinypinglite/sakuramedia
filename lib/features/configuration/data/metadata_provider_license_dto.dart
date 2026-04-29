class MetadataProviderLicenseStatusDto {
  const MetadataProviderLicenseStatusDto({
    required this.configured,
    required this.active,
    this.instanceId,
    this.expiresAt,
    this.licenseValidUntil,
    this.renewAfterSeconds,
    this.errorCode,
    this.message,
  });

  final bool configured;
  final bool active;
  final String? instanceId;
  final int? expiresAt;
  final int? licenseValidUntil;
  final int? renewAfterSeconds;
  final String? errorCode;
  final String? message;

  factory MetadataProviderLicenseStatusDto.fromJson(Map<String, dynamic> json) {
    return MetadataProviderLicenseStatusDto(
      configured: _asBool(json['configured']),
      active: _asBool(json['active']),
      instanceId: json['instance_id'] as String?,
      expiresAt: _asNullableInt(json['expires_at']),
      licenseValidUntil: _asNullableInt(json['license_valid_until']),
      renewAfterSeconds: _asNullableInt(json['renew_after_seconds']),
      errorCode: json['error_code'] as String?,
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'configured': configured,
      'active': active,
      'instance_id': instanceId,
      'expires_at': expiresAt,
      'license_valid_until': licenseValidUntil,
      'renew_after_seconds': renewAfterSeconds,
      'error_code': errorCode,
      'message': message,
    };
  }
}

class MetadataProviderLicenseConnectivityTestDto {
  const MetadataProviderLicenseConnectivityTestDto({
    required this.ok,
    required this.url,
    required this.proxyEnabled,
    required this.elapsedMs,
    this.statusCode,
    this.error,
  });

  final bool ok;
  final String url;
  final bool proxyEnabled;
  final int elapsedMs;
  final int? statusCode;
  final String? error;

  factory MetadataProviderLicenseConnectivityTestDto.fromJson(
    Map<String, dynamic> json,
  ) {
    return MetadataProviderLicenseConnectivityTestDto(
      ok: _asBool(json['ok']),
      url: json['url'] as String? ?? '',
      proxyEnabled: _asBool(json['proxy_enabled']),
      elapsedMs: _asNullableInt(json['elapsed_ms']) ?? 0,
      statusCode: _asNullableInt(json['status_code']),
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'ok': ok,
      'url': url,
      'proxy_enabled': proxyEnabled,
      'elapsed_ms': elapsedMs,
      'status_code': statusCode,
      'error': error,
    };
  }
}

bool _asBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    return value.toLowerCase() == 'true';
  }
  return false;
}

int? _asNullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
