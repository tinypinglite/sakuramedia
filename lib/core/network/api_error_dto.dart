import 'package:sakuramedia/core/json/json_parse.dart';

class ApiErrorDto {
  const ApiErrorDto({required this.code, required this.message, this.details});

  final String code;
  final String message;
  final Map<String, dynamic>? details;

  factory ApiErrorDto.fromJson(Map<String, dynamic> json) {
    return ApiErrorDto(
      code: asStringOrNull(json['code']) ?? 'unknown_error',
      message: asStringOrNull(json['message']) ?? 'Unknown error',
      details: asMapOrNull(json['details']),
    );
  }

  /// 从 `{ "error": {...} }` 响应体解析错误对象；不是该形状时返回 null。
  static ApiErrorDto? tryFromEnvelope(dynamic data) {
    final envelope = asMapOrNull(data);
    if (envelope == null) {
      return null;
    }
    final error = asMapOrNull(envelope['error']);
    return error == null ? null : ApiErrorDto.fromJson(error);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'code': code,
      'message': message,
      if (details != null) 'details': details,
    };
  }
}
