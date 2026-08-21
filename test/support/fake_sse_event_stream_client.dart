import 'dart:async';
import 'dart:convert';

import 'package:sakuramedia/core/network/api_sse_event.dart';
import 'package:sakuramedia/core/network/sse_event_stream_client.dart';

/// 传输层 SSE 假实现：替换 `sseEventStreamClientProvider` /
/// 测试直接向指定 endpoint 注入事件。
///
/// 本类是传输层打桩：
/// 生产代码里 `apiClient.getSse` 的替代品，为仍使用 SSE 的媒体搜索路径提供
/// 集成级测试路径。
///
/// 默认「静默不推事件」（不触发 SSE 消费副作用）；要打事件的测试用 [emit] /
/// [emitError] / [emitUnsupported] 等钩子手动注入。
class FakeSseEventStreamClient implements SseEventStreamClient {
  final Map<String, StreamController<ApiSseEvent>> _controllers = {};

  StreamController<ApiSseEvent> _controllerFor(String endpoint) =>
      _controllers.putIfAbsent(
        endpoint,
        StreamController<ApiSseEvent>.broadcast,
      );

  @override
  Stream<ApiSseEvent> connect(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _controllerFor(endpoint).stream;
  }

  /// 向指定 endpoint 注入一条事件。
  void emit(
    String endpoint, {
    int? id,
    String event = 'message',
    String data = '',
  }) {
    _controllerFor(endpoint).add(
      ApiSseEvent(id: id, event: event, data: data),
    );
  }

  /// 注入一条 JSON 事件（data 自动 jsonEncode）。
  void emitJson(
    String endpoint, {
    int? id,
    String event = 'message',
    Map<String, dynamic>? json,
  }) {
    emit(
      endpoint,
      id: id,
      event: event,
      data: json == null ? '' : jsonEncode(json),
    );
  }

  /// 注入错误：与生产 `getSse` 出错时一样，error 沿 stream 冒泡给消费方。
  void emitError(String endpoint, Object error) {
    _controllerFor(endpoint).addError(error);
  }

  /// 触发「该 endpoint 不支持 SSE」（如 Web 端）：消费方应走 unsupported 分支。
  void emitUnsupported(String endpoint) {
    _controllerFor(endpoint).addError(
      const SseEventStreamUnsupportedException('fake unsupported'),
    );
  }

  /// 关闭全部 endpoint 的连接并清空状态（幂等）。
  void closeAll() {
    for (final controller in _controllers.values) {
      unawaited(controller.close());
    }
    _controllers.clear();
  }

  @override
  void dispose() {
    closeAll();
  }
}
