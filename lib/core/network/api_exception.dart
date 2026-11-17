import 'package:sakuramedia/core/network/api_error_dto.dart';

enum ApiTransportFailureKind { connection, timeout }

class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.error,
    this.transportFailureKind,
    this.baseUrl,
  });

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
  final ApiTransportFailureKind? transportFailureKind;
  final String? baseUrl;

  bool get isTransportFailure => transportFailureKind != null;

  @override
  String toString() {
    return 'ApiException(statusCode: $statusCode, message: $message, error: ${error?.toJson()}, transportFailureKind: $transportFailureKind, baseUrl: $baseUrl)';
  }
}
