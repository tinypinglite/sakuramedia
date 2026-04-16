import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_error_dto.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';

void main() {
  test('formats transport failures with base url', () {
    const error = ApiException(
      message:
          'The connection errored: The XMLHttpRequest onError callback was called.',
      transportFailureKind: ApiTransportFailureKind.connection,
      baseUrl: 'https://api.example.com',
    );

    expect(
      apiErrorMessage(error, fallback: 'fallback'),
      '无法连接到服务器：https://api.example.com。请检查后端地址是否正确、服务是否已启动，或网络是否可达。',
    );
  });

  test('formats timeout transport failures distinctly', () {
    const error = ApiException(
      message: 'Request timed out',
      transportFailureKind: ApiTransportFailureKind.timeout,
      baseUrl: 'https://api.example.com',
    );

    expect(
      apiErrorMessage(error, fallback: 'fallback'),
      '连接服务器超时：https://api.example.com。请检查服务是否繁忙、网络是否稳定，或稍后重试。',
    );
  });

  test('prefers backend business message when payload is available', () {
    const error = ApiException(
      message: 'Request failed',
      error: ApiErrorDto(code: 'invalid_credentials', message: '用户名或密码错误'),
    );

    expect(apiErrorMessage(error, fallback: 'fallback'), '用户名或密码错误');
  });
}
