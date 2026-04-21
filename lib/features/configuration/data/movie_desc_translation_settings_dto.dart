class MovieDescTranslationSettingsDto {
  const MovieDescTranslationSettingsDto({
    required this.enabled,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.timeoutSeconds,
    required this.connectTimeoutSeconds,
  });

  final bool enabled;
  final String baseUrl;
  final String apiKey;
  final String model;
  final double timeoutSeconds;
  final double connectTimeoutSeconds;

  factory MovieDescTranslationSettingsDto.fromJson(Map<String, dynamic> json) {
    return MovieDescTranslationSettingsDto(
      enabled: json['enabled'] as bool? ?? false,
      baseUrl: json['base_url'] as String? ?? '',
      apiKey: json['api_key'] as String? ?? '',
      model: json['model'] as String? ?? '',
      timeoutSeconds: _asDouble(json['timeout_seconds']),
      connectTimeoutSeconds: _asDouble(json['connect_timeout_seconds']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'base_url': baseUrl,
      'api_key': apiKey,
      'model': model,
      'timeout_seconds': timeoutSeconds,
      'connect_timeout_seconds': connectTimeoutSeconds,
    };
  }
}

class UpdateMovieDescTranslationSettingsPayload {
  const UpdateMovieDescTranslationSettingsPayload({
    required this.enabled,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.timeoutSeconds,
    required this.connectTimeoutSeconds,
  });

  final bool enabled;
  final String baseUrl;
  final String apiKey;
  final String model;
  final double timeoutSeconds;
  final double connectTimeoutSeconds;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'base_url': baseUrl,
      'api_key': apiKey,
      'model': model,
      'timeout_seconds': timeoutSeconds,
      'connect_timeout_seconds': connectTimeoutSeconds,
    };
  }
}

class TestMovieDescTranslationSettingsPayload {
  const TestMovieDescTranslationSettingsPayload({
    required this.enabled,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.timeoutSeconds,
    required this.connectTimeoutSeconds,
  });

  final bool enabled;
  final String baseUrl;
  final String apiKey;
  final String model;
  final double timeoutSeconds;
  final double connectTimeoutSeconds;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'base_url': baseUrl,
      'api_key': apiKey,
      'model': model,
      'timeout_seconds': timeoutSeconds,
      'connect_timeout_seconds': connectTimeoutSeconds,
    };
  }
}

double _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return 0;
}
