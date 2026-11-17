import 'dart:math';

import 'package:dio/dio.dart';

const bool _apiDelayEnabled = bool.fromEnvironment('API_DELAY');

/// 通过 `flutter run -d xx --dart-define=API_DELAY=true` 开启，让查询类
/// GET 随机延迟 3~6 秒返回，便于观察骨架屏；写请求、SSE 和字节下载不延迟。
class DebugLatencyInterceptor extends Interceptor {
  DebugLatencyInterceptor({
    this.min = const Duration(seconds: 3),
    this.max = const Duration(seconds: 6),
    Random? random,
  }) : _random = random ?? Random() {
    assert(!min.isNegative && max >= min);
  }

  final Duration min;
  final Duration max;
  final Random _random;

  static DebugLatencyInterceptor? fromEnvironment() {
    return _apiDelayEnabled ? DebugLatencyInterceptor() : null;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_shouldDelay(options)) {
      handler.next(options);
      return;
    }
    _delayThenNext(options, handler);
  }

  Future<void> _delayThenNext(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    await Future<void>.delayed(_nextDelay());
    handler.next(options);
  }

  bool _shouldDelay(RequestOptions options) {
    if (options.method.toUpperCase() != 'GET') {
      return false;
    }
    return options.responseType != ResponseType.stream &&
        options.responseType != ResponseType.bytes;
  }

  Duration _nextDelay() {
    final minMilliseconds = min.inMilliseconds;
    final span = max.inMilliseconds - minMilliseconds;
    if (span <= 0) {
      return min;
    }
    return Duration(milliseconds: minMilliseconds + _random.nextInt(span + 1));
  }
}
