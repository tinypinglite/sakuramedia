import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:sakuramedia/core/media/playback_proxy_policy.dart';

/// Resolves a provider source URL to a loopback URL whose upstream reads follow
/// the provider's [PlaybackProxyPolicy].
abstract interface class PlaybackRangeProxy {
  Future<Uri> localUrlFor(
    String originUrl, {
    required Map<String, String> headers,
    required String cacheKey,
  });

  /// 立即取消 [cacheKey] 对应的下游会话和上游请求。
  ///
  /// 播放器切换媒体或销毁时调用。取消会同步释放该会话占用的上游闸门，
  /// 避免旧媒体在播放器已经断开后继续阻塞新媒体。
  void release(String cacheKey);

  Future<void> dispose();
}

/// A process-local Range proxy for providers that explicitly opt in.
///
/// The HTTP server and all byte forwarding run in a worker isolate. The main
/// isolate only exchanges control messages (origin URL/header registration and
/// disposal); media bytes never cross an isolate boundary. This keeps the
/// proxy's socket and buffer work off the Flutter UI event loop.
class LoopbackRangePlaybackProxy implements PlaybackRangeProxy {
  LoopbackRangePlaybackProxy._(
    this.policy,
    this._isolate,
    this._controlPort,
    this._responsePort,
    this._exitPort,
    this._onLog,
  ) {
    _responseSubscription = _responsePort.listen(_handleResponse);
    _exitSubscription = _exitPort.listen((_) => _handleWorkerExit());
  }

  final PlaybackProxyPolicy policy;
  final Isolate _isolate;
  final SendPort _controlPort;
  final ReceivePort _responsePort;
  final ReceivePort _exitPort;
  final void Function(String message)? _onLog;
  final Map<int, Completer<Uri>> _pendingLocalUrls = <int, Completer<Uri>>{};
  late final StreamSubscription<Object?> _responseSubscription;
  late final StreamSubscription<Object?> _exitSubscription;
  Completer<void>? _disposeCompleter;
  int _nextRequestId = 0;
  bool _disposed = false;

  static final Map<String, Future<PlaybackRangeProxy>> _shared =
      <String, Future<PlaybackRangeProxy>>{};

  static Future<PlaybackRangeProxy> shared(PlaybackProxyPolicy policy) async {
    assert(policy.enabled);
    final existing = _shared[policy.providerKey];
    if (existing != null) {
      return existing;
    }
    final created = create(policy: policy);
    _shared[policy.providerKey] = created;
    try {
      return await created;
    } catch (_) {
      if (identical(_shared[policy.providerKey], created)) {
        _shared.remove(policy.providerKey);
      }
      rethrow;
    }
  }

  static Future<LoopbackRangePlaybackProxy> create({
    required PlaybackProxyPolicy policy,
    void Function(String message)? onLog,
  }) async {
    assert(policy.enabled);
    final readyPort = ReceivePort();
    final responsePort = ReceivePort();
    final exitPort = ReceivePort();
    final isolate = await Isolate.spawn(_proxyIsolateMain, <Object?>[
      readyPort.sendPort,
      responsePort.sendPort,
      _policyToMap(policy),
      onLog != null,
    ], debugName: 'sakuramedia-playback-range-proxy');
    isolate.addOnExitListener(exitPort.sendPort);

    Object? ready;
    try {
      ready = await readyPort.first.timeout(const Duration(seconds: 10));
    } catch (_) {
      isolate.kill(priority: Isolate.immediate);
      responsePort.close();
      exitPort.close();
      rethrow;
    } finally {
      readyPort.close();
    }

    if (ready is! Map || ready['type'] != 'ready') {
      isolate.kill(priority: Isolate.immediate);
      responsePort.close();
      exitPort.close();
      throw StateError('playback proxy isolate failed to start: $ready');
    }
    final controlPort = ready['controlPort'];
    if (controlPort is! SendPort) {
      isolate.kill(priority: Isolate.immediate);
      responsePort.close();
      exitPort.close();
      throw StateError('playback proxy isolate returned no control port');
    }
    return LoopbackRangePlaybackProxy._(
      policy,
      isolate,
      controlPort,
      responsePort,
      exitPort,
      onLog,
    );
  }

  void _handleResponse(Object? message) {
    if (message is! Map) {
      return;
    }
    switch (message['type']) {
      case 'log':
        final text = message['message'];
        if (text is String) {
          _onLog?.call(text);
        }
        break;
      case 'localUrlResult':
        final id = message['id'];
        final uri = message['uri'];
        if (id is int && uri is String) {
          _pendingLocalUrls.remove(id)?.complete(Uri.parse(uri));
        }
        break;
      case 'localUrlError':
        final id = message['id'];
        final error = message['error'];
        if (id is int) {
          _pendingLocalUrls
              .remove(id)
              ?.completeError(StateError(error?.toString() ?? 'proxy failed'));
        }
        break;
      case 'disposed':
        _disposeCompleter?.complete();
        break;
    }
  }

  /// 从共享表移除当前实例。
  ///
  /// isolate 异常退出后如果仍留在 [_shared] 里，后续播放会一直命中这个
  /// 已销毁的代理并静默回退到直连，115 的并发保护随之失效，只有重启 App
  /// 才能恢复。退出和显式 dispose 都必须把位置腾出来，让下一次播放重新创建。
  void _forgetSharedInstance() {
    final shared = _shared[policy.providerKey];
    if (shared == null) {
      return;
    }
    unawaited(
      shared
          .then((proxy) {
            if (identical(proxy, this) &&
                identical(_shared[policy.providerKey], shared)) {
              _shared.remove(policy.providerKey);
            }
          })
          .catchError((_) {}),
    );
  }

  void _handleWorkerExit() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _forgetSharedInstance();
    for (final completer in _pendingLocalUrls.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('playback proxy isolate exited unexpectedly'),
        );
      }
    }
    _pendingLocalUrls.clear();
    _disposeCompleter?.complete();
    unawaited(_responseSubscription.cancel());
    unawaited(_exitSubscription.cancel());
    _responsePort.close();
    _exitPort.close();
  }

  @override
  Future<Uri> localUrlFor(
    String originUrl, {
    required Map<String, String> headers,
    required String cacheKey,
  }) async {
    if (_disposed) {
      throw StateError('playback proxy has been disposed');
    }
    final id = _nextRequestId++;
    final completer = Completer<Uri>();
    _pendingLocalUrls[id] = completer;
    _controlPort.send(<String, Object?>{
      'type': 'localUrl',
      'id': id,
      'originUrl': originUrl,
      'headers': Map<String, String>.from(headers),
      'cacheKey': cacheKey,
    });
    try {
      return await completer.future.timeout(const Duration(seconds: 10));
    } finally {
      _pendingLocalUrls.remove(id);
    }
  }

  @override
  void release(String cacheKey) {
    if (_disposed) {
      return;
    }
    _controlPort.send(<String, Object?>{
      'type': 'release',
      'cacheKey': cacheKey,
    });
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    final completer = Completer<void>();
    _disposeCompleter = completer;
    try {
      _controlPort.send(const <String, Object?>{'type': 'dispose'});
      await completer.future.timeout(const Duration(seconds: 5));
    } catch (_) {
      // The isolate is killed below even if graceful shutdown timed out.
    } finally {
      await _responseSubscription.cancel();
      await _exitSubscription.cancel();
      _responsePort.close();
      _exitPort.close();
      _isolate.kill(priority: Isolate.immediate);
      _disposeCompleter = null;
      for (final pending in _pendingLocalUrls.values) {
        if (!pending.isCompleted) {
          pending.completeError(StateError('playback proxy has been disposed'));
        }
      }
      _pendingLocalUrls.clear();
      _forgetSharedInstance();
    }
  }
}

class _LoopbackRangePlaybackProxyWorker implements PlaybackRangeProxy {
  static const int _downstreamFlushBytes = 256 * 1024;
  static const Duration _downstreamFlushInterval = Duration(milliseconds: 16);

  _LoopbackRangePlaybackProxyWorker._(this.policy, this._server, this._onLog);

  final PlaybackProxyPolicy policy;
  final HttpServer _server;
  final void Function(String message)? _onLog;
  final Map<String, _PlaybackOrigin> _origins = <String, _PlaybackOrigin>{};
  final Set<_StreamSession> _sessions = <_StreamSession>{};
  bool _disposed = false;

  static Future<_LoopbackRangePlaybackProxyWorker> create({
    required PlaybackProxyPolicy policy,
    void Function(String message)? onLog,
  }) async {
    assert(policy.enabled);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final proxy = _LoopbackRangePlaybackProxyWorker._(policy, server, onLog);
    server.listen(proxy._handle, onError: (_) {});
    return proxy;
  }

  @override
  Future<Uri> localUrlFor(
    String originUrl, {
    required Map<String, String> headers,
    required String cacheKey,
  }) async {
    final origin = Uri.tryParse(originUrl);
    if (origin == null) {
      throw ArgumentError.value(originUrl, 'originUrl', 'invalid URL');
    }
    _origins[cacheKey] = _PlaybackOrigin(origin, <String, String>{
      ...policy.defaultUpstreamHeaders,
      ...headers,
    }, policy.maxConcurrentUpstreamRequests);
    return Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: _server.port,
      path: '/v',
      queryParameters: <String, String>{'k': cacheKey},
    );
  }

  @override
  void release(String cacheKey) {
    for (final session in _sessions.toList()) {
      if (session.key == cacheKey) {
        session.cancel();
      }
    }
    _origins.remove(cacheKey);
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    final key = request.uri.queryParameters['k'];
    final origin = key == null ? null : _origins[key];
    if (key == null || origin == null) {
      response.statusCode = HttpStatus.notFound;
      await _closeQuietly(response);
      return;
    }

    final stopwatch = Stopwatch()..start();
    final rawRange = request.headers.value(HttpHeaders.rangeHeader);
    final range = rawRange == null ? null : _RangeRequest.tryParse(rawRange);
    if (rawRange != null && range == null) {
      response.statusCode = HttpStatus.badRequest;
      await _closeQuietly(response);
      return;
    }

    // A player may keep the previous loopback request open after a seek.
    // Abort it explicitly so its upstream window cannot block the new seek.
    _cancelSessionsForKey(key);
    final session = _StreamSession(key, origin, policy);
    _sessions.add(session);
    try {
      response.bufferOutput = false;
      _log('▶ ${request.method} key=$key range=${rawRange ?? '(none)'}');

      if (request.method == 'HEAD' || range == null || range.start == null) {
        await _serveWithKnownTotal(session, response, range, request.method);
      } else {
        await _serveForwardRange(session, response, range);
      }

      if (!session.cancelled) {
        await response.close();
      } else {
        await _closeQuietly(response);
      }
      _log(
        '■ key=$key range=${rawRange ?? '(none)'} '
        'in ${stopwatch.elapsedMilliseconds}ms',
      );
    } on _RangeNotSatisfiable catch (error) {
      if (!session.responseStarted) {
        _resetResponse(response);
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes */${error.total}',
        );
      }
      await _closeQuietly(response);
    } on _ProxyTimeout catch (error) {
      if (session.cancelled) {
        await _closeQuietly(response);
        return;
      }
      if (!session.responseStarted) {
        _resetResponse(response);
        response.statusCode = HttpStatus.gatewayTimeout;
        response.headers.contentLength = 0;
      }
      _log('✗ key=$key timeout: ${error.message}');
      await _closeQuietly(response);
    } on _SessionCancelled {
      await _closeQuietly(response);
    } catch (error) {
      if (session.cancelled) {
        await _closeQuietly(response);
        return;
      }
      if (!session.responseStarted) {
        _resetResponse(response);
        response.statusCode = HttpStatus.badGateway;
        response.headers.contentLength = 0;
      }
      _log('✗ key=$key ${error.runtimeType}');
      await _closeQuietly(response);
    } finally {
      session.close();
      _sessions.remove(session);
    }
  }

  void _cancelSessionsForKey(String key) {
    for (final session in _sessions.toList()) {
      if (session.key == key) {
        session.cancel();
      }
    }
  }

  Future<void> _serveForwardRange(
    _StreamSession session,
    HttpResponse response,
    _RangeRequest range,
  ) async {
    final start = range.start!;
    final requestedEnd = range.end;
    final first = await _withGate(session, () async {
      final maxWindowEnd = start + policy.upstreamWindowBytes - 1;
      final firstEnd = requestedEnd == null
          ? maxWindowEnd
          : math.min(requestedEnd, maxWindowEnd);
      final opened = await _openWindowWithRetry(session, start, firstEnd);
      if (opened == null) {
        throw const HttpException('upstream range request failed');
      }
      final knownTotal = opened.totalLength;
      if (knownTotal == null || knownTotal <= 0) {
        await _discardResponse(session, opened.response);
        throw const HttpException('upstream did not report total length');
      }
      final end = requestedEnd == null
          ? knownTotal - 1
          : math.min(requestedEnd, knownTotal - 1);
      if (start >= knownTotal || start > end) {
        await _discardResponse(session, opened.response);
        throw _RangeNotSatisfiable(knownTotal);
      }
      _setRangeHeaders(response, session.origin, start, end, knownTotal);
      final windowEnd = math.min(opened.end, end);
      await _pipeWindow(session, response, opened.response, start, windowEnd);
      return (total: knownTotal, end: end, windowEnd: windowEnd);
    });

    final total = first.total;
    final end = first.end;
    var position = first.windowEnd + 1;
    while (position <= end && !session.cancelled) {
      final nextWindowEnd = math.min(
        position + policy.upstreamWindowBytes - 1,
        end,
      );
      var nextPosition = position;
      await _withGate(session, () async {
        final opened = await _openWindowWithRetry(
          session,
          position,
          nextWindowEnd,
        );
        if (opened == null) {
          throw const HttpException('upstream range request failed');
        }
        if (opened.totalLength != null && opened.totalLength != total) {
          await _discardResponse(session, opened.response);
          throw const HttpException('upstream total length changed');
        }
        final actualEnd = math.min(opened.end, nextWindowEnd);
        await _pipeWindow(
          session,
          response,
          opened.response,
          position,
          actualEnd,
        );
        nextPosition = actualEnd + 1;
      });
      if (nextPosition <= position) {
        throw const HttpException('upstream returned an empty range');
      }
      position = nextPosition;
    }
  }

  Future<void> _serveWithKnownTotal(
    _StreamSession session,
    HttpResponse response,
    _RangeRequest? range,
    String method,
  ) async {
    final total = await _withGate(session, () async {
      final opened = await _openWindowWithRetry(session, 0, 0);
      if (opened == null) {
        throw const HttpException('upstream length probe failed');
      }
      final value = opened.totalLength;
      await _discardResponse(session, opened.response);
      return value;
    });
    if (total == null || total <= 0) {
      throw const HttpException('upstream did not report total length');
    }

    final start = range == null
        ? 0
        : (range.start ?? math.max(0, total - range.suffixLength!));
    final end = range == null
        ? total - 1
        : (range.end == null ? total - 1 : math.min(range.end!, total - 1));
    if (start >= total || start > end) {
      throw _RangeNotSatisfiable(total);
    }

    response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    response.headers.set(
      HttpHeaders.contentTypeHeader,
      session.origin.contentType ?? 'video/mp4',
    );
    if (range == null) {
      response.statusCode = HttpStatus.ok;
      response.headers.contentLength = total;
    } else {
      _setRangeHeaders(response, session.origin, start, end, total);
    }
    if (method == 'HEAD') {
      return;
    }

    var position = start;
    while (position <= end && !session.cancelled) {
      final windowEnd = math.min(
        position + policy.upstreamWindowBytes - 1,
        end,
      );
      var nextPosition = position;
      await _withGate(session, () async {
        final opened = await _openWindowWithRetry(session, position, windowEnd);
        if (opened == null) {
          throw const HttpException('upstream range request failed');
        }
        if (opened.totalLength != null && opened.totalLength != total) {
          await _discardResponse(session, opened.response);
          throw const HttpException('upstream total length changed');
        }
        final actualEnd = math.min(opened.end, windowEnd);
        await _pipeWindow(
          session,
          response,
          opened.response,
          position,
          actualEnd,
        );
        nextPosition = actualEnd + 1;
      });
      if (nextPosition <= position) {
        throw const HttpException('upstream returned an empty range');
      }
      position = nextPosition;
    }
  }

  Future<T> _withGate<T>(
    _StreamSession session,
    Future<T> Function() action,
  ) async {
    final gate = session.origin.gate;
    await gate.acquire();
    session.gateHeld = true;
    try {
      if (session.cancelled) {
        throw const _SessionCancelled();
      }
      return await action();
    } finally {
      if (!session.cancelled && policy.cooldown > Duration.zero) {
        await Future<void>.delayed(policy.cooldown);
      }
      session.releaseGate();
    }
  }

  Future<_OpenedWindow?> _openWindowWithRetry(
    _StreamSession session,
    int start,
    int end,
  ) async {
    for (var attempt = 1; attempt <= policy.maxAttempts; attempt++) {
      if (session.cancelled) {
        return null;
      }
      try {
        final opened = await _openWithRedirects(session, start, end);
        final status = opened.response.statusCode;
        if (_shouldRetry(status) && attempt < policy.maxAttempts) {
          await _discardResponse(session, opened.response);
          session.origin.resolvedUrl = null;
          session.resetClient();
          await Future<void>.delayed(policy.retryDelay);
          continue;
        }
        if (status != HttpStatus.partialContent) {
          await _discardResponse(session, opened.response);
          session.resetClient();
          return null;
        }
        final range = _parseContentRange(opened.response);
        if (range == null || range.start != start) {
          await _discardResponse(session, opened.response);
          session.resetClient();
          return null;
        }
        final contentType = opened.response.headers.contentType?.toString();
        if (contentType != null) {
          session.origin.contentType ??= contentType;
        }
        _log('↑ window $start-${range.end}');
        return _OpenedWindow(opened.response, range.total, range.end);
      } on _ProxyTimeout {
        session.resetClient();
        if (attempt < policy.maxAttempts) {
          await Future<void>.delayed(policy.retryDelay);
          continue;
        }
        rethrow;
      } catch (error) {
        if (session.cancelled) {
          return null;
        }
        _log('✗ open range $start-$end failed: ${error.runtimeType}');
        session.resetClient();
        if (attempt < policy.maxAttempts) {
          await Future<void>.delayed(policy.retryDelay);
          continue;
        }
        return null;
      }
    }
    return null;
  }

  Future<_OpenedResponse> _openWithRedirects(
    _StreamSession session,
    int start,
    int end,
  ) async {
    var url = session.origin.resolvedUrl ?? session.origin.url;
    for (var redirect = 0; redirect <= 5; redirect++) {
      final request = await session.client.getUrl(url);
      request
        ..followRedirects = false
        ..persistentConnection = policy.keepAlive;
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      session.origin.headers.forEach(request.headers.set);
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-$end');
      final response = await request.close().timeout(
        policy.upstreamTimeout,
        onTimeout: () {
          request.abort();
          throw const _ProxyTimeout('upstream response headers timed out');
        },
      );
      if (!_isRedirect(response.statusCode)) {
        session.origin.resolvedUrl = url;
        return _OpenedResponse(response);
      }
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain<void>().timeout(policy.upstreamTimeout);
      if (location == null || location.isEmpty) {
        throw const HttpException('redirect without Location');
      }
      url = url.resolve(location);
    }
    throw const HttpException('too many redirects');
  }

  Future<void> _pipeWindow(
    _StreamSession session,
    HttpResponse response,
    HttpClientResponse upstream,
    int start,
    int end,
  ) async {
    final expected = end - start + 1;
    if (expected <= 0) {
      await _discardResponse(session, upstream);
      return;
    }

    var received = 0;
    var bytesSinceFlush = 0;
    final flushStopwatch = Stopwatch()..start();
    try {
      await for (final data in upstream.timeout(policy.upstreamTimeout)) {
        if (session.cancelled) {
          return;
        }
        final remaining = expected - received;
        if (remaining <= 0) {
          // Drain extras without forwarding so the connection can return to
          // the keep-alive pool instead of being torn down by cancellation.
          continue;
        }
        final take = math.min(remaining, data.length);
        final bytes = take == data.length ? data : data.sublist(0, take);
        try {
          session.responseStarted = true;
          response.add(bytes);
          received += take;
          bytesSinceFlush += take;
          final shouldFlush =
              received == take ||
              bytesSinceFlush >= _downstreamFlushBytes ||
              flushStopwatch.elapsed >= _downstreamFlushInterval;
          if (shouldFlush) {
            await response.flush().timeout(policy.downstreamFlushTimeout);
            bytesSinceFlush = 0;
            flushStopwatch.reset();
          }
          if (session.cancelled) {
            return;
          }
        } catch (_) {
          session.cancelled = true;
          return;
        }
      }
    } on TimeoutException {
      throw const _ProxyTimeout('upstream response body timed out');
    }
    if (!session.cancelled && received < expected) {
      throw const HttpException('upstream range ended early');
    }
    if (!session.cancelled) {
      if (bytesSinceFlush > 0) {
        try {
          await response.flush().timeout(policy.downstreamFlushTimeout);
        } catch (_) {
          session.cancelled = true;
          return;
        }
      }
      _log('↓ window $start-$end ${received}B');
    }
  }

  Future<void> _discardResponse(
    _StreamSession session,
    HttpClientResponse response,
  ) async {
    try {
      await response.drain<void>().timeout(policy.upstreamTimeout);
    } catch (_) {
      session.resetClient();
    }
  }

  void _setRangeHeaders(
    HttpResponse response,
    _PlaybackOrigin origin,
    int start,
    int end,
    int total,
  ) {
    response.statusCode = HttpStatus.partialContent;
    response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    response.headers.set(
      HttpHeaders.contentTypeHeader,
      origin.contentType ?? 'video/mp4',
    );
    response.headers.contentLength = end - start + 1;
    response.headers.set(
      HttpHeaders.contentRangeHeader,
      'bytes $start-$end/$total',
    );
  }

  static bool _isRedirect(int statusCode) =>
      statusCode == HttpStatus.movedPermanently ||
      statusCode == HttpStatus.found ||
      statusCode == HttpStatus.seeOther ||
      statusCode == HttpStatus.temporaryRedirect ||
      statusCode == HttpStatus.permanentRedirect;

  static bool _shouldRetry(int statusCode) =>
      statusCode == HttpStatus.forbidden ||
      statusCode == HttpStatus.tooManyRequests ||
      statusCode >= 500;

  static _ParsedContentRange? _parseContentRange(HttpClientResponse response) {
    final value = response.headers.value(HttpHeaders.contentRangeHeader);
    final match = RegExp(
      r'^bytes\s+(\d+)-(\d+)/(\d+|\*)$',
    ).firstMatch(value ?? '');
    if (match == null) {
      return null;
    }
    final start = int.tryParse(match.group(1)!);
    final end = int.tryParse(match.group(2)!);
    final totalText = match.group(3)!;
    final total = totalText == '*' ? null : int.tryParse(totalText);
    if (start == null || end == null) {
      return null;
    }
    return _ParsedContentRange(start, end, total);
  }

  static void _resetResponse(HttpResponse response) {
    try {
      response.headers.clear();
    } catch (_) {}
  }

  Future<void> _closeQuietly(HttpResponse response) async {
    try {
      await response.close();
    } catch (_) {}
  }

  void _log(String message) => _onLog?.call(message);

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    for (final session in _sessions.toList()) {
      session.cancel();
    }
    _sessions.clear();
    for (final origin in _origins.values) {
      origin.gate.close();
    }
    _origins.clear();
    try {
      await _server.close(force: true);
    } catch (_) {}
  }
}

Future<void> _proxyIsolateMain(List<Object?> args) async {
  final readyPort = args[0] as SendPort;
  final responsePort = args[1] as SendPort;
  final policy = _policyFromMap(args[2] as Map<Object?, Object?>);
  final logEnabled = args[3] as bool;
  final controlPort = ReceivePort();
  _LoopbackRangePlaybackProxyWorker? worker;
  var disposed = false;

  try {
    final activeWorker = await _LoopbackRangePlaybackProxyWorker.create(
      policy: policy,
      onLog: logEnabled
          ? (message) => responsePort.send(<String, Object?>{
              'type': 'log',
              'message': message,
            })
          : null,
    );
    worker = activeWorker;
    readyPort.send(<String, Object?>{
      'type': 'ready',
      'controlPort': controlPort.sendPort,
    });

    await for (final message in controlPort) {
      if (message is! Map) {
        continue;
      }
      final type = message['type'];
      if (type == 'localUrl') {
        final id = message['id'];
        final originUrl = message['originUrl'];
        final cacheKey = message['cacheKey'];
        final headers = message['headers'];
        if (id is! int ||
            originUrl is! String ||
            cacheKey is! String ||
            headers is! Map) {
          if (id is int) {
            responsePort.send(<String, Object?>{
              'type': 'localUrlError',
              'id': id,
              'error': 'invalid local URL request',
            });
          }
          continue;
        }
        try {
          final uri = await activeWorker.localUrlFor(
            originUrl,
            headers: Map<String, String>.from(headers),
            cacheKey: cacheKey,
          );
          responsePort.send(<String, Object?>{
            'type': 'localUrlResult',
            'id': id,
            'uri': uri.toString(),
          });
        } catch (error) {
          responsePort.send(<String, Object?>{
            'type': 'localUrlError',
            'id': id,
            'error': error.toString(),
          });
        }
      } else if (type == 'release') {
        final cacheKey = message['cacheKey'];
        if (cacheKey is String) {
          activeWorker.release(cacheKey);
        }
      } else if (type == 'dispose') {
        disposed = true;
        await activeWorker.dispose();
        responsePort.send(const <String, Object?>{'type': 'disposed'});
        controlPort.close();
        return;
      }
    }
  } catch (error) {
    readyPort.send(<String, Object?>{
      'type': 'error',
      'error': error.toString(),
    });
  } finally {
    controlPort.close();
    if (!disposed) {
      await worker?.dispose();
    }
  }
}

Map<String, Object?> _policyToMap(PlaybackProxyPolicy policy) =>
    <String, Object?>{
      'providerKey': policy.providerKey,
      'enabled': policy.enabled,
      'maxConcurrentUpstreamRequests': policy.maxConcurrentUpstreamRequests,
      'upstreamWindowBytes': policy.upstreamWindowBytes,
      'upstreamTimeout': policy.upstreamTimeout.inMicroseconds,
      'downstreamFlushTimeout': policy.downstreamFlushTimeout.inMicroseconds,
      'retryDelay': policy.retryDelay.inMicroseconds,
      'maxAttempts': policy.maxAttempts,
      'cooldown': policy.cooldown.inMicroseconds,
      'keepAlive': policy.keepAlive,
      'idleConnectionTimeout': policy.idleConnectionTimeout.inMicroseconds,
      'defaultUpstreamHeaders': Map<String, String>.from(
        policy.defaultUpstreamHeaders,
      ),
      'volatileQueryKeys': policy.volatileQueryKeys.toList(growable: false),
    };

PlaybackProxyPolicy _policyFromMap(Map<Object?, Object?> map) =>
    PlaybackProxyPolicy(
      providerKey: map['providerKey'] as String,
      enabled: map['enabled'] as bool,
      maxConcurrentUpstreamRequests:
          map['maxConcurrentUpstreamRequests'] as int,
      upstreamWindowBytes: map['upstreamWindowBytes'] as int,
      upstreamTimeout: Duration(microseconds: map['upstreamTimeout'] as int),
      downstreamFlushTimeout: Duration(
        microseconds: map['downstreamFlushTimeout'] as int,
      ),
      retryDelay: Duration(microseconds: map['retryDelay'] as int),
      maxAttempts: map['maxAttempts'] as int,
      cooldown: Duration(microseconds: map['cooldown'] as int),
      keepAlive: map['keepAlive'] as bool,
      idleConnectionTimeout: Duration(
        microseconds: map['idleConnectionTimeout'] as int,
      ),
      defaultUpstreamHeaders: Map<String, String>.from(
        map['defaultUpstreamHeaders'] as Map,
      ),
      volatileQueryKeys: Set<String>.from(map['volatileQueryKeys'] as List),
    );

class _PlaybackOrigin {
  _PlaybackOrigin(this.url, this.headers, int maxConcurrentRequests)
    : gate = _UpstreamGate(maxConcurrentRequests);

  final Uri url;
  final Map<String, String> headers;

  /// 每一条播放链接各自的上游闸门，不同链接互不影响。
  final _UpstreamGate gate;
  Uri? resolvedUrl;
  String? contentType;
}

class _StreamSession {
  _StreamSession(this.key, this.origin, this._policy)
    : client = _createClient(_policy);

  final String key;
  final _PlaybackOrigin origin;
  final PlaybackProxyPolicy _policy;
  HttpClient client;
  bool cancelled = false;
  bool responseStarted = false;
  bool gateHeld = false;

  static HttpClient _createClient(PlaybackProxyPolicy policy) {
    final client = HttpClient()
      ..connectionTimeout = policy.upstreamTimeout
      ..idleTimeout = policy.idleConnectionTimeout
      ..maxConnectionsPerHost = 1;
    return client;
  }

  void resetClient() {
    close();
    client = _createClient(_policy);
  }

  void cancel() {
    cancelled = true;
    close();
    releaseGate();
  }

  void releaseGate() {
    if (!gateHeld) {
      return;
    }
    gateHeld = false;
    origin.gate.release();
  }

  void close() {
    try {
      client.close(force: true);
    } catch (_) {}
  }
}

class _UpstreamGate {
  _UpstreamGate(this.maxConcurrentRequests);

  final int maxConcurrentRequests;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();
  int _activeRequests = 0;
  bool _closed = false;

  Future<void> acquire() async {
    if (_closed) {
      throw const _SessionCancelled();
    }
    if (_activeRequests < maxConcurrentRequests) {
      _activeRequests++;
      return;
    }
    final waiter = Completer<void>();
    _waiters.add(waiter);
    await waiter.future;
  }

  void release() {
    if (_closed) {
      return;
    }
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
    } else {
      _activeRequests--;
    }
  }

  void close() {
    _closed = true;
    while (_waiters.isNotEmpty) {
      _waiters.removeFirst().completeError(const _SessionCancelled());
    }
  }
}

class _OpenedResponse {
  _OpenedResponse(this.response);

  final HttpClientResponse response;
}

class _OpenedWindow {
  _OpenedWindow(this.response, this.totalLength, this.end);

  final HttpClientResponse response;
  final int? totalLength;
  final int end;
}

class _ParsedContentRange {
  const _ParsedContentRange(this.start, this.end, this.total);

  final int start;
  final int end;
  final int? total;
}

class _RangeRequest {
  const _RangeRequest({this.start, this.end, this.suffixLength});

  final int? start;
  final int? end;
  final int? suffixLength;

  static _RangeRequest? tryParse(String value) {
    final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(value.trim());
    if (match == null) {
      return null;
    }
    final startText = match.group(1)!;
    final endText = match.group(2)!;
    if (startText.isEmpty && endText.isEmpty) {
      return null;
    }
    if (startText.isEmpty) {
      final suffix = int.tryParse(endText);
      if (suffix == null || suffix <= 0) {
        return null;
      }
      return _RangeRequest(suffixLength: suffix);
    }
    final start = int.tryParse(startText);
    final end = endText.isEmpty ? null : int.tryParse(endText);
    if (start == null || (end != null && end < start)) {
      return null;
    }
    return _RangeRequest(start: start, end: end);
  }
}

class _RangeNotSatisfiable implements Exception {
  const _RangeNotSatisfiable(this.total);

  final int total;
}

class _ProxyTimeout implements Exception {
  const _ProxyTimeout(this.message);

  final String message;
}

class _SessionCancelled implements Exception {
  const _SessionCancelled();
}
