import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:sakuramedia/core/media/bounded_range_cache_store.dart';
import 'package:sakuramedia/core/media/playback_proxy_policy.dart';
import 'package:streaming_video_cache/streaming_video_cache.dart';

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
/// The player talks to loopback, while [BoundedConcurrencyUpstream] enforces
/// the provider's upstream concurrency and the bounded chunk cache avoids
/// repeatedly downloading the same ranges.
class LoopbackRangePlaybackProxy implements PlaybackRangeProxy {
  LoopbackRangePlaybackProxy._(this.policy, this._server);

  final PlaybackProxyPolicy policy;
  final VideoCacheServer _server;

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
    Directory? cacheDirectory,
    UpstreamClient? upstream,
  }) async {
    assert(policy.enabled);
    final directory =
        cacheDirectory ??
        Directory(
          '${(await getTemporaryDirectory()).path}/playback_ranges/'
          '${policy.providerKey}',
        );
    final store = BoundedRangeCacheStore(
      directory: directory,
      maxBytes: policy.maxCacheBytes,
      maxEntryBytes: policy.maxEntryBytes,
      chunkSize: policy.chunkSize,
    );
    await store.init();
    final server = VideoCacheServer(
      store: store,
      upstream:
          upstream ??
          BoundedConcurrencyUpstream(
            maxConcurrentRequests: policy.maxConcurrentUpstreamRequests,
            cooldown: policy.cooldown,
          ),
    );
    await server.start();
    return LoopbackRangePlaybackProxy._(policy, server);
  }

  @override
  Future<Uri> localUrlFor(
    String originUrl, {
    required Map<String, String> headers,
    required String cacheKey,
  }) async {
    return _server.localUrlFor(
      originUrl,
      headers: <String, String>{...policy.defaultUpstreamHeaders, ...headers},
      cacheKey: cacheKey,
    );
  }

  @override
  Future<void> dispose() => _server.stop();
}

/// Enforces the policy-level upstream concurrency and retries transient
/// PMT/rate-limit failures. The byte-range cache coalesces identical chunks,
/// while this gate bounds different seek requests against the provider.
class BoundedConcurrencyUpstream implements UpstreamClient {
  static const _maxBufferedResponseBytes = 32 * 1024 * 1024;

  BoundedConcurrencyUpstream({
    required int maxConcurrentRequests,
    HttpClient? client,
    Duration timeout = const Duration(seconds: 30),
    Duration retryDelay = const Duration(milliseconds: 400),
    Duration cooldown = const Duration(milliseconds: 20),
    int maxAttempts = 3,
  }) : this._(
         maxConcurrentRequests,
         client ?? HttpClient(),
         timeout,
         retryDelay,
         cooldown,
         maxAttempts,
       );

  BoundedConcurrencyUpstream._(
    this._maxConcurrentRequests,
    this._client,
    this._timeout,
    this._retryDelay,
    this._cooldown,
    this._maxAttempts,
  ) : assert(_maxConcurrentRequests > 0) {
    _configureClient();
  }

  void _configureClient() {
    _client.connectionTimeout = _timeout;
    _client.maxConnectionsPerHost = _maxConcurrentRequests;
  }

  final int _maxConcurrentRequests;
  HttpClient _client;
  final Duration _timeout;
  final Duration _retryDelay;
  final Duration _cooldown;
  final int _maxAttempts;

  int _activeRequests = 0;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  @override
  Future<UpstreamResponse?> fetchRange(
    Uri url,
    Map<String, String> headers,
    int start,
    int end,
  ) async {
    await _acquire();
    try {
      return await _fetchRangeWithRetry(url, headers, start, end);
    } finally {
      if (_cooldown > Duration.zero) {
        await Future<void>.delayed(_cooldown);
      }
      _release();
    }
  }

  Future<void> _acquire() async {
    if (_activeRequests < _maxConcurrentRequests) {
      _activeRequests++;
      return;
    }
    final waiter = Completer<void>();
    _waiters.add(waiter);
    await waiter.future;
  }

  void _release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
    } else {
      _activeRequests--;
    }
  }

  Future<UpstreamResponse?> _fetchRangeWithRetry(
    Uri url,
    Map<String, String> headers,
    int start,
    int end,
  ) async {
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      HttpClientRequest? request;
      HttpClientResponse? response;
      try {
        final opened = await _openWithRedirects(
          url,
          headers,
          start: start,
          end: end,
        );
        request = opened.request;
        response = opened.response;
        if (_shouldRetry(response.statusCode) && attempt < _maxAttempts) {
          await _drainResponse(response);
          await Future<void>.delayed(_retryDelay);
          continue;
        }
        if (response.statusCode != HttpStatus.ok &&
            response.statusCode != HttpStatus.partialContent) {
          await _drainResponse(response);
          return null;
        }
        if (response.statusCode == HttpStatus.ok &&
            response.contentLength > _maxBufferedResponseBytes) {
          await _forceClose(request);
          return null;
        }

        final totalLength = _totalLength(response);
        final contentType = response.headers.contentType?.toString();
        final bytes = await _readBody(response, request);
        return UpstreamResponse(
          statusCode: response.statusCode,
          bytes: bytes,
          totalLength: totalLength,
          contentType: contentType,
        );
      } catch (_) {
        await _forceClose(request);
        if (attempt < _maxAttempts) {
          await Future<void>.delayed(_retryDelay);
          continue;
        }
        return null;
      }
    }
    return null;
  }

  Future<Uint8List> _readBody(
    HttpClientResponse response,
    HttpClientRequest request,
  ) async {
    final builder = BytesBuilder(copy: false);
    await _consumeBody(response, builder).timeout(_timeout);
    return builder.takeBytes();
  }

  Future<void> _drainResponse(HttpClientResponse response) async {
    await response.drain<void>().timeout(
      _timeout,
      onTimeout: () {
        throw TimeoutException('upstream response body timed out');
      },
    );
  }

  Future<void> _consumeBody(
    HttpClientResponse response,
    BytesBuilder builder,
  ) async {
    await for (final chunk in response) {
      builder.add(chunk);
      if (builder.length > _maxBufferedResponseBytes) {
        throw const HttpException(
          'upstream response body is unexpectedly large',
        );
      }
    }
  }

  Future<void> _forceClose(HttpClientRequest? request) async {
    try {
      request?.abort();
    } catch (_) {}
    try {
      _client.close(force: true);
    } catch (_) {}
    _client = HttpClient();
    _configureClient();
  }

  Future<({HttpClientRequest request, HttpClientResponse response})>
  _openWithRedirects(
    Uri initialUrl,
    Map<String, String> headers, {
    required int start,
    required int end,
  }) async {
    var url = initialUrl;
    for (var redirect = 0; redirect <= 5; redirect++) {
      final request = await _client.getUrl(url);
      request
        ..followRedirects = false
        ..persistentConnection = false;
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      headers.forEach(request.headers.set);
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-$end');
      final HttpClientResponse response;
      try {
        response = await request.close().timeout(
          _timeout,
          onTimeout: () {
            request.abort();
            throw TimeoutException('upstream response headers timed out');
          },
        );
      } catch (_) {
        request.abort();
        rethrow;
      }
      if (!_isRedirect(response.statusCode)) {
        return (request: request, response: response);
      }
      final location = response.headers.value(HttpHeaders.locationHeader);
      await _drainResponse(response);
      if (location == null || location.isEmpty) {
        throw const HttpException('redirect without Location');
      }
      url = url.resolve(location);
    }
    throw const HttpException('too many redirects');
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

  static int? _totalLength(HttpClientResponse response) {
    if (response.statusCode == HttpStatus.partialContent) {
      final contentRange = response.headers.value(
        HttpHeaders.contentRangeHeader,
      );
      final match = RegExp(r'/(\d+)\s*$').firstMatch(contentRange ?? '');
      return match == null ? null : int.tryParse(match.group(1)!);
    }
    if (response.statusCode == HttpStatus.ok && response.contentLength > 0) {
      return response.contentLength;
    }
    return null;
  }

  @override
  void close() {
    try {
      _client.close(force: true);
    } catch (_) {}
  }
}
