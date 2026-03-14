import 'package:sakuramedia/core/network/api_error_dto.dart';

class ApiException implements Exception {
  const ApiException({required this.message, this.statusCode, this.error});

  factory ApiException.unauthorized({
    String code = 'unauthorized',
    String message = 'Unauthorized',
  }) {
    return ApiException(
      message: message,
      statusCode: 401,
      error: ApiErrorDto(code: code, message: message),
    );
  }

  final String message;
  final int? statusCode;
  final ApiErrorDto? error;

  @override
  String toString() {
    return 'ApiException(statusCode: $statusCode, message: $message, error: ${error?.toJson()})';
  }
}
