import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef AdapterResponder =
    Future<ResponseBody> Function(RequestOptions options, dynamic requestBody);

class RecordedRequest {
  const RecordedRequest({
    required this.method,
    required this.path,
    required this.uri,
    required this.headers,
    required this.body,
    required this.receiveTimeout,
  });

  final String method;
  final String path;
  final Uri uri;
  final Map<String, dynamic> headers;
  final dynamic body;
  final Duration? receiveTimeout;
}

class FakeHttpClientAdapter implements HttpClientAdapter {
  final Map<String, Queue<AdapterResponder>> _responderQueues =
      <String, Queue<AdapterResponder>>{};
  final List<RecordedRequest> requests = <RecordedRequest>[];

  void enqueueJson({
    required String method,
    required String path,
    int statusCode = 200,
    dynamic body,
    Map<String, List<String>>? headers,
  }) {
    enqueueResponder(
      method: method,
      path: path,
      responder: (RequestOptions _, dynamic __) async {
        if (statusCode == 204) {
          return ResponseBody.fromBytes(
            const <int>[],
            statusCode,
            headers: headers ?? const <String, List<String>>{},
          );
        }
        return ResponseBody.fromString(
          jsonEncode(body ?? const <String, dynamic>{}),
          statusCode,
          headers:
              headers ??
              const <String, List<String>>{
                Headers.contentTypeHeader: <String>[Headers.jsonContentType],
              },
        );
      },
    );
  }

  void enqueueBytes({
    required String method,
    required String path,
    int statusCode = 200,
    required Uint8List body,
    Map<String, List<String>>? headers,
  }) {
    enqueueResponder(
      method: method,
      path: path,
      responder: (RequestOptions _, dynamic __) async {
        return ResponseBody.fromBytes(
          body,
          statusCode,
          headers: headers ?? const <String, List<String>>{},
        );
      },
    );
  }

  void enqueueSse({
    required String method,
    required String path,
    int statusCode = 200,
    required List<String> chunks,
    Duration chunkInterval = Duration.zero,
    Map<String, List<String>>? headers,
  }) {
    enqueueResponder(
      method: method,
      path: path,
      responder: (RequestOptions _, dynamic __) async {
        return ResponseBody(
          _buildSseStream(chunks: chunks, chunkInterval: chunkInterval),
          statusCode,
          headers:
              headers ??
              const <String, List<String>>{
                Headers.contentTypeHeader: <String>['text/event-stream'],
              },
        );
      },
    );
  }

  void enqueueResponder({
    required String method,
    required String path,
    required AdapterResponder responder,
  }) {
    final key = _routeKey(method, path);
    _responderQueues.putIfAbsent(key, () => Queue<AdapterResponder>());
    _responderQueues[key]!.add(responder);
  }

  int hitCount(String method, String path) {
    return requests
        .where(
          (RecordedRequest request) =>
              request.method.toUpperCase() == method.toUpperCase() &&
              request.path == path,
        )
        .length;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final requestBody = await _decodeRequestBody(options, requestStream);
    requests.add(
      RecordedRequest(
        method: options.method,
        path: options.path,
        uri: options.uri,
        headers: Map<String, dynamic>.from(options.headers),
        body: requestBody,
        receiveTimeout: options.receiveTimeout,
      ),
    );

    final key = _routeKey(options.method, options.path);
    final queue = _responderQueues[key];
    if (queue == null || queue.isEmpty) {
      throw StateError(
        'No queued response for ${options.method} ${options.path}',
      );
    }

    return queue.removeFirst().call(options, requestBody);
  }

  @override
  void close({bool force = false}) {
    _responderQueues.clear();
    requests.clear();
  }

  String _routeKey(String method, String path) {
    return '${method.toUpperCase()} $path';
  }

  Future<dynamic> _decodeRequestBody(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
  ) async {
    if (options.data != null) {
      return options.data;
    }
    if (requestStream == null) {
      return null;
    }

    final chunks = <int>[];
    await for (final Uint8List chunk in requestStream) {
      chunks.addAll(chunk);
    }
    if (chunks.isEmpty) {
      return null;
    }

    final rawText = utf8.decode(chunks);
    try {
      return jsonDecode(rawText);
    } catch (_) {
      return rawText;
    }
  }

  Stream<Uint8List> _buildSseStream({
    required List<String> chunks,
    required Duration chunkInterval,
  }) async* {
    for (final chunk in chunks) {
      if (chunkInterval > Duration.zero) {
        await Future<void>.delayed(chunkInterval);
      }
      yield Uint8List.fromList(utf8.encode(chunk));
    }
  }
}
