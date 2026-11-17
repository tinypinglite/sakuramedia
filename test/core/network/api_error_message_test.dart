import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_error_dto.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/l10n/app_localizations_en.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';

void main() {
  final zh = AppLocalizationsZh();
  final en = AppLocalizationsEn();

  group('transport failures', () {
    test('带 base url 时提示里带上 host', () {
      const error = ApiException(
        message: 'Request timed out',
        transportFailureKind: ApiTransportFailureKind.timeout,
        baseUrl: 'https://api.example.com',
      );

      expect(
        apiErrorMessage(error, fallback: 'fallback', l10n: zh),
        contains('https://api.example.com'),
      );
    });

    test('没有 base url 时提示里不带 host', () {
      const error = ApiException(
        message: 'Request timed out',
        transportFailureKind: ApiTransportFailureKind.timeout,
      );

      final message = apiErrorMessage(error, fallback: 'fallback', l10n: zh);
      expect(message, isNot(contains('://')));
    });

    test('空白 base url 按没有 host 处理', () {
      const error = ApiException(
        message: 'Request timed out',
        transportFailureKind: ApiTransportFailureKind.timeout,
        baseUrl: '   ',
      );

      final message = apiErrorMessage(error, fallback: 'fallback', l10n: zh);
      expect(message, isNot(contains('://')));
    });

    test('中英文提示不同', () {
      const error = ApiException(
        message: 'Request timed out',
        transportFailureKind: ApiTransportFailureKind.timeout,
        baseUrl: 'https://api.example.com',
      );

      expect(
        apiErrorMessage(error, fallback: 'fallback', l10n: zh),
        isNot(apiErrorMessage(error, fallback: 'fallback', l10n: en)),
      );
    });

    test('连接失败与超时失败是不同文案', () {
      const timeout = ApiException(
        message: 'Request timed out',
        transportFailureKind: ApiTransportFailureKind.timeout,
      );
      const connection = ApiException(
        message: 'The connection errored.',
        transportFailureKind: ApiTransportFailureKind.connection,
      );

      expect(
        apiErrorMessage(timeout, fallback: 'fallback', l10n: zh),
        isNot(apiErrorMessage(connection, fallback: 'fallback', l10n: zh)),
      );
    });
  });

  group('non-transport failures', () {
    test('优先展示后端业务文案', () {
      const error = ApiException(
        message: 'raw message',
        error: ApiErrorDto(code: 'x', message: '后端提示'),
      );

      expect(apiErrorMessage(error, fallback: 'fallback', l10n: zh), '后端提示');
    });

    test('没有后端 DTO 时用异常自带文案', () {
      const error = ApiException(message: 'raw message');

      expect(
        apiErrorMessage(error, fallback: 'fallback', l10n: zh),
        'raw message',
      );
    });

    test('非 ApiException 用 fallback', () {
      expect(
        apiErrorMessage(StateError('boom'), fallback: 'fallback', l10n: zh),
        'fallback',
      );
    });
  });
}
