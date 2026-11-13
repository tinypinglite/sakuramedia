import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/media/playback_proxy_policy.dart';
import 'package:sakuramedia/core/media/playback_range_proxy.dart';

const _cloud115UserAgent = 'Mozilla/5.0; Darwin/10.0; UDown/39.1.0';

void main() {
  HttpOverrides? previousHttpOverrides;

  setUp(() {
    previousHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
  });

  tearDown(() {
    HttpOverrides.global = previousHttpOverrides;
  });

  test('follows redirect, forwards UA and retries one 403', () async {
    final origin = await _RangeOrigin.start(failFirstVideoRequest: true);
    final proxy = await LoopbackRangePlaybackProxy.create(
      policy: cloud115PlaybackProxyPolicy.copyWith(
        upstreamWindowBytes: 64 * 1024,
        retryDelay: const Duration(milliseconds: 20),
        cooldown: Duration.zero,
      ),
    );
    addTearDown(() async {
      await proxy.dispose();
      await origin.stop();
    });

    final localUrl = await proxy.localUrlFor(
      origin.startUrl,
      headers: const <String, String>{'User-Agent': _cloud115UserAgent},
      cacheKey: 'redirect-retry',
    );
    final response = await _get(localUrl, range: 'bytes=0-65535');

    expect(response.statusCode, HttpStatus.partialContent);
    expect(response.body, origin.bytes.sublist(0, 64 * 1024));
    expect(origin.videoRequestCount, greaterThanOrEqualTo(2));
    expect(origin.userAgents, everyElement(_cloud115UserAgent));
  });

  test('new seek cancels the previous local request', () async {
    final origin = await _RangeOrigin.start(stallFirstVideoAfterHeaders: true);
    final proxy = await LoopbackRangePlaybackProxy.create(
      policy: cloud115PlaybackProxyPolicy.copyWith(
        upstreamWindowBytes: 64 * 1024,
        cooldown: Duration.zero,
      ),
    );
    addTearDown(() async {
      await proxy.dispose();
      await origin.stop();
    });

    final localUrl = await proxy.localUrlFor(
      origin.startUrl,
      headers: const <String, String>{'User-Agent': _cloud115UserAgent},
      cacheKey: 'latest-seek-wins',
    );
    final first = _get(
      localUrl,
      range: 'bytes=0-65535',
    ).catchError((_) => _RangeResponse(0, Uint8List(0)));
    await _waitUntil(() => origin.videoRequestCount >= 1);

    final second = await _get(localUrl, range: 'bytes=131072-196607');
    await first;

    expect(second.statusCode, HttpStatus.partialContent);
    expect(second.body, origin.bytes.sublist(128 * 1024, 192 * 1024));
    expect(origin.videoRequestCount, greaterThanOrEqualTo(2));
  });

  test('one gate slot serializes different media', () async {
    final origin = await _RangeOrigin.start(
      responseDelay: const Duration(milliseconds: 80),
    );
    final proxy = await LoopbackRangePlaybackProxy.create(
      policy: cloud115PlaybackProxyPolicy.copyWith(
        upstreamWindowBytes: 64 * 1024,
        cooldown: Duration.zero,
      ),
    );
    addTearDown(() async {
      await proxy.dispose();
      await origin.stop();
    });

    final firstUrl = await proxy.localUrlFor(
      origin.startUrl,
      headers: const <String, String>{'User-Agent': _cloud115UserAgent},
      cacheKey: 'serialized-a',
    );
    final secondUrl = await proxy.localUrlFor(
      origin.startUrl,
      headers: const <String, String>{'User-Agent': _cloud115UserAgent},
      cacheKey: 'serialized-b',
    );
    final responses = await Future.wait([
      _get(firstUrl, range: 'bytes=0-65535'),
      _get(secondUrl, range: 'bytes=131072-196607'),
    ]);

    expect(
      responses.map((response) => response.statusCode),
      everyElement(HttpStatus.partialContent),
    );
    expect(origin.maxActiveVideoRequests, 1);
  });

  test('policy concurrency can allow two upstream streams', () async {
    final origin = await _RangeOrigin.start(
      responseDelay: const Duration(milliseconds: 80),
    );
    final proxy = await LoopbackRangePlaybackProxy.create(
      policy: cloud115PlaybackProxyPolicy.copyWith(
        maxConcurrentUpstreamRequests: 2,
        upstreamWindowBytes: 64 * 1024,
        cooldown: Duration.zero,
      ),
    );
    addTearDown(() async {
      await proxy.dispose();
      await origin.stop();
    });

    final firstUrl = await proxy.localUrlFor(
      origin.startUrl,
      headers: const <String, String>{'User-Agent': _cloud115UserAgent},
      cacheKey: 'concurrency-two-a',
    );
    final secondUrl = await proxy.localUrlFor(
      origin.startUrl,
      headers: const <String, String>{'User-Agent': _cloud115UserAgent},
      cacheKey: 'concurrency-two-b',
    );
    final responses = await Future.wait([
      _get(firstUrl, range: 'bytes=0-65535'),
      _get(secondUrl, range: 'bytes=131072-196607'),
    ]);

    expect(
      responses.map((response) => response.statusCode),
      everyElement(HttpStatus.partialContent),
    );
    expect(origin.maxActiveVideoRequests, 2);
  });

  test('reuses one upstream connection across sequential windows', () async {
    final origin = await _RangeOrigin.start();
    final proxy = await LoopbackRangePlaybackProxy.create(
      policy: cloud115PlaybackProxyPolicy.copyWith(
        upstreamWindowBytes: 64 * 1024,
        cooldown: Duration.zero,
      ),
    );
    addTearDown(() async {
      await proxy.dispose();
      await origin.stop();
    });

    final localUrl = await proxy.localUrlFor(
      origin.startUrl,
      headers: const <String, String>{'User-Agent': _cloud115UserAgent},
      cacheKey: 'keep-alive',
    );
    final response = await _get(localUrl, range: 'bytes=0-${192 * 1024 - 1}');

    expect(response.statusCode, HttpStatus.partialContent);
    expect(response.body, origin.bytes.sublist(0, 192 * 1024));
    expect(origin.requestedRanges, hasLength(3));
    expect(origin.activeUpstreamPorts, hasLength(1));
  });

  test('streams first bytes before the full upstream window arrives', () async {
    final origin = await _RangeOrigin.start(
      initialBodyBytes: 16 * 1024,
      bodyChunkDelay: const Duration(milliseconds: 600),
    );
    final proxy = await LoopbackRangePlaybackProxy.create(
      policy: cloud115PlaybackProxyPolicy.copyWith(
        upstreamWindowBytes: 256 * 1024,
        cooldown: Duration.zero,
      ),
    );
    addTearDown(() async {
      await proxy.dispose();
      await origin.stop();
    });

    final localUrl = await proxy.localUrlFor(
      origin.startUrl,
      headers: const <String, String>{'User-Agent': _cloud115UserAgent},
      cacheKey: 'streaming-first-byte',
    );
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final stopwatch = Stopwatch()..start();
    final request = await client.getUrl(localUrl);
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-${256 * 1024 - 1}');
    final response = await request.close();
    final firstChunkAt = Completer<int>();
    final body = BytesBuilder(copy: false);
    final subscription = response.listen((data) {
      if (!firstChunkAt.isCompleted) {
        firstChunkAt.complete(stopwatch.elapsedMilliseconds);
      }
      body.add(data);
    });

    final firstChunkMs = await firstChunkAt.future.timeout(
      const Duration(seconds: 2),
    );
    await subscription.asFuture<void>();

    expect(firstChunkMs, lessThan(400));
    expect(stopwatch.elapsedMilliseconds, greaterThan(500));
    expect(body.takeBytes(), origin.bytes.sublist(0, 256 * 1024));
  });

  test('times out a stalled upstream and releases the queue', () async {
    final origin = await _RangeOrigin.start(stallFirstVideoBody: true);
    final proxy = await LoopbackRangePlaybackProxy.create(
      policy: cloud115PlaybackProxyPolicy.copyWith(
        upstreamWindowBytes: 64 * 1024,
        upstreamTimeout: const Duration(milliseconds: 100),
        retryDelay: const Duration(milliseconds: 10),
        maxAttempts: 1,
        cooldown: Duration.zero,
      ),
    );
    addTearDown(() async {
      await proxy.dispose();
      await origin.stop();
    });

    final localUrl = await proxy.localUrlFor(
      origin.startUrl,
      headers: const <String, String>{'User-Agent': _cloud115UserAgent},
      cacheKey: 'stalled-body',
    );
    final stopwatch = Stopwatch()..start();
    final stalled = await _get(localUrl, range: 'bytes=0-65535');

    expect(stalled.statusCode, HttpStatus.gatewayTimeout);
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));

    final nextStopwatch = Stopwatch()..start();
    final next = await _get(localUrl, range: 'bytes=65536-131071');
    expect(nextStopwatch.elapsed, lessThan(const Duration(seconds: 1)));
    expect(next.statusCode, HttpStatus.partialContent);
    expect(next.body, origin.bytes.sublist(64 * 1024, 128 * 1024));
  });

  test('open-ended range streams across windows and ends at total', () async {
    final origin = await _RangeOrigin.start();
    final proxy = await LoopbackRangePlaybackProxy.create(
      policy: cloud115PlaybackProxyPolicy.copyWith(
        upstreamWindowBytes: 64 * 1024,
        cooldown: Duration.zero,
      ),
    );
    addTearDown(() async {
      await proxy.dispose();
      await origin.stop();
    });

    final localUrl = await proxy.localUrlFor(
      origin.startUrl,
      headers: const <String, String>{'User-Agent': _cloud115UserAgent},
      cacheKey: 'open-ended',
    );
    const start = 128 * 1024;
    final response = await _get(localUrl, range: 'bytes=$start-');

    expect(response.statusCode, HttpStatus.partialContent);
    expect(response.body, origin.bytes.sublist(start));
    expect(origin.requestedRanges.first, 'bytes=$start-${start + 65536 - 1}');
    expect(origin.activeUpstreamPorts, hasLength(1));
  });

  test('suffix range probes total length and returns the tail', () async {
    final origin = await _RangeOrigin.start();
    final proxy = await LoopbackRangePlaybackProxy.create(
      policy: cloud115PlaybackProxyPolicy.copyWith(
        upstreamWindowBytes: 64 * 1024,
        cooldown: Duration.zero,
      ),
    );
    addTearDown(() async {
      await proxy.dispose();
      await origin.stop();
    });

    final localUrl = await proxy.localUrlFor(
      origin.startUrl,
      headers: const <String, String>{'User-Agent': _cloud115UserAgent},
      cacheKey: 'suffix',
    );
    final response = await _get(localUrl, range: 'bytes=-65536');

    expect(response.statusCode, HttpStatus.partialContent);
    expect(response.body, origin.bytes.sublist(origin.bytes.length - 65536));
    expect(origin.requestedRanges.first, 'bytes=0-0');
  });
}

class _RangeResponse {
  const _RangeResponse(this.statusCode, this.body);

  final int statusCode;
  final Uint8List body;
}

Future<_RangeResponse> _get(Uri url, {required String range}) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(url);
    request.headers.set(HttpHeaders.rangeHeader, range);
    final response = await request.close();
    final body = BytesBuilder(copy: false);
    await for (final chunk in response) {
      body.add(chunk);
    }
    return _RangeResponse(response.statusCode, body.takeBytes());
  } finally {
    client.close(force: true);
  }
}

Future<void> _waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue);
}

class _RangeOrigin {
  _RangeOrigin._(
    this._server,
    this.bytes, {
    required this.failFirstVideoRequest,
    required this.responseDelay,
    required this.stallFirstVideoBody,
    required this.stallFirstVideoAfterHeaders,
    required this.initialBodyBytes,
    required this.bodyChunkDelay,
  });

  final HttpServer _server;
  final Uint8List bytes;
  final bool failFirstVideoRequest;
  final Duration responseDelay;
  final bool stallFirstVideoBody;
  final bool stallFirstVideoAfterHeaders;
  final int initialBodyBytes;
  final Duration bodyChunkDelay;
  final List<String> userAgents = <String>[];
  final Set<int> activeUpstreamPorts = <int>{};
  final List<String> requestedRanges = <String>[];
  int videoRequestCount = 0;
  int activeVideoRequests = 0;
  int maxActiveVideoRequests = 0;

  String get startUrl => 'http://127.0.0.1:${_server.port}/start';

  static Future<_RangeOrigin> start({
    bool failFirstVideoRequest = false,
    Duration responseDelay = Duration.zero,
    bool stallFirstVideoBody = false,
    bool stallFirstVideoAfterHeaders = false,
    int initialBodyBytes = 0,
    Duration bodyChunkDelay = Duration.zero,
  }) async {
    final bytes = Uint8List.fromList(
      List<int>.generate(2 * 1024 * 1024, (index) => index % 251),
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final origin = _RangeOrigin._(
      server,
      bytes,
      failFirstVideoRequest: failFirstVideoRequest,
      responseDelay: responseDelay,
      stallFirstVideoBody: stallFirstVideoBody,
      stallFirstVideoAfterHeaders: stallFirstVideoAfterHeaders,
      initialBodyBytes: initialBodyBytes,
      bodyChunkDelay: bodyChunkDelay,
    );
    server.listen(origin._handle);
    return origin;
  }

  Future<void> stop() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    if (request.uri.path == '/start') {
      response
        ..statusCode = HttpStatus.found
        ..headers.set(HttpHeaders.locationHeader, '/video');
      await response.close();
      return;
    }
    if (request.uri.path != '/video') {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }

    videoRequestCount++;
    final range = request.headers.value(HttpHeaders.rangeHeader);
    if (range != null) {
      requestedRanges.add(range);
    }
    final remotePort = request.connectionInfo?.remotePort;
    if (remotePort != null) {
      activeUpstreamPorts.add(remotePort);
    }
    final userAgent = request.headers.value(HttpHeaders.userAgentHeader);
    if (userAgent != null) {
      userAgents.add(userAgent);
    }
    if (userAgent != _cloud115UserAgent ||
        (failFirstVideoRequest && videoRequestCount == 1)) {
      response.statusCode = HttpStatus.forbidden;
      await response.close();
      return;
    }

    activeVideoRequests++;
    if (activeVideoRequests > maxActiveVideoRequests) {
      maxActiveVideoRequests = activeVideoRequests;
    }
    try {
      if (responseDelay > Duration.zero) {
        await Future<void>.delayed(responseDelay);
      }
      final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range ?? '');
      final start = match == null ? 0 : int.parse(match.group(1)!);
      final endText = match?.group(2) ?? '';
      final end = endText.isEmpty ? bytes.length - 1 : int.parse(endText);
      final slice = bytes.sublist(start, end + 1);
      response
        ..statusCode = HttpStatus.partialContent
        ..headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/${bytes.length}',
        )
        ..headers.contentLength = slice.length
        ..headers.contentType = ContentType('video', 'mp4')
        ..bufferOutput = false;

      if (stallFirstVideoBody && videoRequestCount == 1) {
        response.add(const <int>[]);
        await response.flush();
        await Future<void>.delayed(const Duration(seconds: 2));
        return;
      }

      if (stallFirstVideoAfterHeaders && videoRequestCount == 1) {
        response.add(slice.sublist(0, 1));
        await response.flush();
        await Future<void>.delayed(const Duration(seconds: 2));
        return;
      }

      if (bodyChunkDelay > Duration.zero && initialBodyBytes > 0) {
        final first = math.min(initialBodyBytes, slice.length);
        response.add(slice.sublist(0, first));
        await response.flush();
        await Future<void>.delayed(bodyChunkDelay);
        response.add(slice.sublist(first));
      } else {
        response.add(slice);
      }
      await response.close();
    } catch (_) {
      await response.close();
    } finally {
      activeVideoRequests--;
    }
  }
}
