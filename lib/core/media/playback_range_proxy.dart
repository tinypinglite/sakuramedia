import 'dart:async';
import 'dart:collection';
import 'dart:io';
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

  Future<void> dispose();
}

/// A process-local Range proxy for providers that explicitly opt in.
///
/// The player sees one continuous loopback response. Upstream is read in
/// bounded windows: each window is streamed to the player as soon as bytes
/// arrive, and the next window starts only after the previous one is fully
/// consumed. This keeps the number of concurrent provider connections bounded
/// without splitting the player-visible stream into blocking cache chunks.
class LoopbackRangePlaybackProxy implements PlaybackRangeProxy {
  LoopbackRangePlaybackProxy._(this.policy, this._server, this._onLog)
    : _gate = _UpstreamGate(policy.maxConcurrentUpstreamRequests);

  final PlaybackProxyPolicy policy;
  final HttpServer _server;
  final void Function(String message)? _onLog;
  final _UpstreamGate _gate;
  final Map<String, _PlaybackOrigin> _origins = <String, _PlaybackOrigin>{};
  final Set<_StreamSession> _sessions = <_StreamSession>{};
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
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final proxy = LoopbackRangePlaybackProxy._(policy, server, onLog);
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
    });
    return Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: _server.port,
      path: '/v',
      queryParameters: <String, String>{'k': cacheKey},
    );
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
    final session = _StreamSession(key, origin, policy, _gate);
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
    await _gate.acquire();
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
          await response.flush().timeout(policy.downstreamFlushTimeout);
          if (session.cancelled) {
            return;
          }
        } catch (_) {
          session.cancelled = true;
          return;
        }
        received += take;
      }
    } on TimeoutException {
      throw const _ProxyTimeout('upstream response body timed out');
    }
    if (!session.cancelled && received < expected) {
      throw const HttpException('upstream range ended early');
    }
    if (!session.cancelled) {
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
    _origins.clear();
    _gate.close();
    try {
      await _server.close(force: true);
    } catch (_) {}
  }
}

class _PlaybackOrigin {
  _PlaybackOrigin(this.url, this.headers);

  final Uri url;
  final Map<String, String> headers;
  Uri? resolvedUrl;
  String? contentType;
}

class _StreamSession {
  _StreamSession(this.key, this.origin, this._policy, this._gate)
    : client = _createClient(_policy);

  final String key;
  final _PlaybackOrigin origin;
  final PlaybackProxyPolicy _policy;
  final _UpstreamGate _gate;
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
    _gate.release();
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
