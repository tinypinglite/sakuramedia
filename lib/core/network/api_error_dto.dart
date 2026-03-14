class ApiErrorDto {
  const ApiErrorDto({required this.code, required this.message, this.details});

  final String code;
  final String message;
  final Map<String, dynamic>? details;

  factory ApiErrorDto.fromJson(Map<String, dynamic> json) {
    final rawDetails = json['details'];
    return ApiErrorDto(
      code: json['code'] as String? ?? 'unknown_error',
      message: json['message'] as String? ?? 'Unknown error',
      details:
          rawDetails is Map
              ? rawDetails.map(
                (dynamic key, dynamic value) => MapEntry(key.toString(), value),
              )
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'code': code,
      'message': message,
      if (details != null) 'details': details,
    };
  }
}

typedef ApiErrorPayload = ApiErrorDto;
