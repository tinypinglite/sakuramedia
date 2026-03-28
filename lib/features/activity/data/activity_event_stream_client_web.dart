import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:sakuramedia/core/network/api_error_dto.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/network/api_sse_event.dart';
import 'package:sakuramedia/core/network/sse_decoder.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/activity/data/activity_event_stream_client.dart';
import 'package:web/web.dart'
    as web show
        AbortController,
        DOMException,
        HeadersInit,
        ReadableStreamDefaultReader,
        ReadableStreamReadResult,
        RequestInfo,
        RequestInit,
        Response;

import 'package:sakuramedia/core/network/api_client.dart';

@JS('fetch')
external JSPromise<web.Response> _fetch(
  web.RequestInfo input, [
  web.RequestInit init,
]);

ActivityEventStreamClient createPlatformActivityEventStreamClient({
  required ApiClient apiClient,
  required SessionStore sessionStore,
}) {
  return _WebActivityEventStreamClient(sessionStore: sessionStore);
}

class _WebActivityEventStreamClient implements ActivityEventStreamClient {
  _WebActivityEventStreamClient({required SessionStore sessionStore})
    : _sessionStore = sessionStore;

  final SessionStore _sessionStore;
  final List<web.AbortController> _openRequestAbortControllers =
      <web.AbortController>[];
  bool _isDisposed = false;

  @override
  Stream<ApiSseEvent> connect({required int afterEventId}) async* {
    if (_isDisposed) {
      throw const ActivityEventStreamUnsupportedException('stream client closed');
    }
    if (_sessionStore.baseUrl.isEmpty || _sessionStore.accessToken.isEmpty) {
      throw ApiException.unauthorized(
        code: 'unauthorized',
        message: 'Activity stream requires an authenticated session',
      );
    }

    final abortController = web.AbortController();
    _openRequestAbortControllers.add(abortController);
    try {
      final response = await _fetch(
        _buildStreamUri(afterEventId).toString().toJS,
        web.RequestInit(
          method: 'GET',
          credentials: 'same-origin',
          headers: <String, String>{
                'Accept': 'text/event-stream',
                'Authorization': 'Bearer ${_sessionStore.accessToken}',
              }.jsify()
              as web.HeadersInit,
          signal: abortController.signal,
        ),
      ).toDart;

      if (response.status >= 400) {
        final body = (await response.text().toDart).toDart;
        throw _mapErrorResponse(response.status, body);
      }

      final bodyStream = response.body;
      if (bodyStream == null) {
        throw const ActivityEventStreamUnsupportedException(
          'ReadableStream is unavailable in the current browser environment',
        );
      }

      yield* _bodyToStream(response, abortController).transform(
        const SseDecoder(),
      );
    } finally {
      _openRequestAbortControllers.remove(abortController);
    }
  }

  @override
  void dispose() {
    for (final controller in _openRequestAbortControllers) {
      controller.abort();
    }
    _openRequestAbortControllers.clear();
    _isDisposed = true;
  }

  Uri _buildStreamUri(int afterEventId) {
    final baseUrl = _sessionStore.baseUrl.trim();
    final normalizedBaseUrl =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$normalizedBaseUrl/system/events/stream').replace(
      queryParameters: <String, String>{
        'after_event_id': '$afterEventId',
      },
    );
  }

  ApiException _mapErrorResponse(int statusCode, String body) {
    final decoded = _tryDecodeJson(body);
    final payload = _extractErrorPayload(decoded);
    return ApiException(
      statusCode: statusCode,
      message: payload?.message ?? 'Request failed',
      error: payload,
    );
  }

  dynamic _tryDecodeJson(String value) {
    try {
      return jsonDecode(value);
    } catch (_) {
      return null;
    }
  }

  ApiErrorDto? _extractErrorPayload(dynamic value) {
    if (value is! Map) {
      return null;
    }
    final rawError = value['error'];
    if (rawError is! Map) {
      return null;
    }
    return ApiErrorDto.fromJson(
      rawError.map(
        (dynamic key, dynamic data) => MapEntry(key.toString(), data),
      ),
    );
  }

  Stream<Uint8List> _bodyToStream(
    web.Response response,
    web.AbortController abortController,
  ) {
    final requestUri = _buildStreamUri(0);
    return Stream<Uint8List>.multi(
      (controller) => _readStreamBody(
        requestUri: requestUri,
        response: response,
        abortController: abortController,
        controller: controller,
      ),
    );
  }

  Future<void> _readStreamBody({
    required Uri requestUri,
    required web.Response response,
    required web.AbortController abortController,
    required MultiStreamController<Uint8List> controller,
  }) async {
    final reader =
        response.body?.getReader() as web.ReadableStreamDefaultReader?;
    if (reader == null) {
      controller.addError(
        const ActivityEventStreamUnsupportedException(
          'ReadableStream reader is unavailable in the current browser environment',
        ),
      );
      await controller.close();
      return;
    }

    Completer<void>? resumeSignal;
    var cancelled = false;
    var hadError = false;
    controller
      ..onResume = () {
        if (resumeSignal case final resume?) {
          resumeSignal = null;
          resume.complete();
        }
      }
      ..onCancel = () async {
        cancelled = true;
        abortController.abort();
        try {
          await reader.cancel().toDart;
        } catch (_) {
          // Ignore cancellation errors from an already-closed stream.
        }
      };

    while (true) {
      final web.ReadableStreamReadResult chunk;
      try {
        chunk = await reader.read().toDart;
      } catch (error, stackTrace) {
        if (!cancelled) {
          hadError = true;
          controller.addError(
            _mapReaderError(error, requestUri),
            stackTrace,
          );
          await controller.close();
        }
        break;
      }

      if (chunk.done) {
        controller.closeSync();
        break;
      }

      controller.addSync((chunk.value! as JSUint8Array).toDart);

      if (controller.isPaused) {
        await (resumeSignal ??= Completer<void>()).future;
      }
      if (!controller.hasListener) {
        break;
      }
    }

    if (!hadError && cancelled && controller.hasListener) {
      await controller.close();
    }
  }

  Object _mapReaderError(Object error, Uri requestUri) {
    if (error case web.DOMException(name: 'AbortError')) {
      return ApiException(
        message: 'Activity stream aborted',
        statusCode: null,
      );
    }
    if (error is ApiException ||
        error is ActivityEventStreamUnsupportedException) {
      return error;
    }
    return ApiException(message: error.toString());
  }
}
