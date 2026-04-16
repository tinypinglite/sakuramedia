import 'package:sakuramedia/core/network/api_exception.dart';

String apiErrorMessage(Object error, {required String fallback}) {
  if (error is ApiException) {
    if (error.isTransportFailure) {
      return _transportFailureMessage(error);
    }
    return error.error?.message ?? error.message;
  }
  return fallback;
}

String _transportFailureMessage(ApiException error) {
  final baseUrl = error.baseUrl?.trim();
  return switch (error.transportFailureKind) {
    ApiTransportFailureKind.timeout when baseUrl != null && baseUrl.isNotEmpty =>
      '连接服务器超时：$baseUrl。请检查服务是否繁忙、网络是否稳定，或稍后重试。',
    ApiTransportFailureKind.timeout =>
      '连接服务器超时。请检查服务是否繁忙、网络是否稳定，或稍后重试。',
    _ when baseUrl != null && baseUrl.isNotEmpty =>
      '无法连接到服务器：$baseUrl。请检查后端地址是否正确、服务是否已启动，或网络是否可达。',
    _ => '无法连接到服务器。请检查后端地址是否正确、服务是否已启动，或网络是否可达。',
  };
}
