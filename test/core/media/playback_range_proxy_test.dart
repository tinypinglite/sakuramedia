import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/media/playback_interleave.dart';
import 'package:sakuramedia/core/media/playback_proxy_policy.dart';
import 'package:sakuramedia/core/media/playback_range_proxy.dart';

import 'mp4_layout_fixture.dart';

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

  for (final fastStart in <bool>[false, true]) {
    test('moov 交错异常时静态解析发出信号（${fastStart ? 'faststart' : '尾部'}）', () async {
      final file = buildMp4TestFile(abnormal: true, fastStart: fastStart);
      final origin = await _RangeOrigin.start(bodyBytes: file.bytes);
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
      final signals = <PlaybackInterleaveSignal>[];
      final subscription = proxy.interleaveSignals.listen(signals.add);
      addTearDown(subscription.cancel);

      final localUrl = await proxy.localUrlFor(
        origin.startUrl,
        headers: const <String, String>{'User-Agent': _cloud115UserAgent},
        cacheKey: 'moov-layout',
      );
      final response = await _get(
        localUrl,
        range: fastStart
            ? 'bytes=0-${file.moovStart + file.moovLength - 1}'
            : 'bytes=${file.moovStart}-${file.bytes.length - 1}',
      );

      expect(response.statusCode, HttpStatus.partialContent);
      expect(
        response.body,
        hasLength(
          fastStart ? file.moovStart + file.moovLength : file.moovLength,
        ),
      );
      await _waitUntil(() => signals.isNotEmpty);
      expect(signals.single.cacheKey, 'moov-layout');
      expect(signals.single.source, PlaybackInterleaveSource.mp4Layout);
      expect(signals.single.maxDistanceBytes, greaterThan(4000000000));
    });
  }

  test('先读尾部 free 再读 moov 仍能静态解析', () async {
    final file = buildMp4TestFile(
      abnormal: true,
      trailingFreeBytes: 1024 * 1024,
    );
    final origin = await _RangeOrigin.start(bodyBytes: file.bytes);
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
    final signals = <PlaybackInterleaveSignal>[];
    final subscription = proxy.interleaveSignals.listen(signals.add);
    addTearDown(subscription.cancel);

    final localUrl = await proxy.localUrlFor(
      origin.startUrl,
      headers: const <String, String>{'User-Agent': _cloud115UserAgent},
      cacheKey: 'moov-after-free',
    );
    final tailResponse = await _get(
      localUrl,
      range:
          'bytes=${file.bytes.length - 64 * 1024}-'
          '${file.bytes.length - 1}',
    );
    expect(tailResponse.statusCode, HttpStatus.partialContent);

    final moovResponse = await _get(
      localUrl,
      range:
          'bytes=${file.moovStart}-'
          '${file.moovStart + file.moovLength - 1}',
    );
    expect(moovResponse.statusCode, HttpStatus.partialContent);
    await _waitUntil(() => signals.isNotEmpty);
    expect(signals.single.source, PlaybackInterleaveSource.mp4Layout);
  });

  test('非 MP4 容器读到 moov 字节也不会做静态解析', () async {
    final moov = buildMoov(
      videoOffsets: <int>[
        for (var index = 0; index < 300; index++) index * 10000000,
      ],
      audioOffsets: <int>[
        for (var index = 0; index < 300; index++) 5000000000 + index * 10000000,
      ],
      useCo64: true,
    );
    final body =
        (BytesBuilder()
              ..add(<int>[0x1A, 0x45, 0xDF, 0xA3, 0x01, 0x00, 0x00, 0x00])
              ..add(List<int>.filled(1024 * 1024, 0))
              ..add(moov))
            .takeBytes();
    final origin = await _RangeOrigin.start(bodyBytes: body);
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
    final signals = <PlaybackInterleaveSignal>[];
    final subscription = proxy.interleaveSignals.listen(signals.add);
    addTearDown(subscription.cancel);

    final localUrl = await proxy.localUrlFor(
      origin.startUrl,
      headers: const <String, String>{'User-Agent': _cloud115UserAgent},
      cacheKey: 'not-mp4',
    );
    final headResponse = await _get(localUrl, range: 'bytes=0-65535');
    expect(headResponse.statusCode, HttpStatus.partialContent);

    final moovStart = body.length - moov.length;
    final tailResponse = await _get(
      localUrl,
      range: 'bytes=$moovStart-${body.length - 1}',
    );
    expect(tailResponse.statusCode, HttpStatus.partialContent);

    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(signals, isEmpty);
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

  test('retries a 410 expired upstream range', () async {
    final origin = await _RangeOrigin.start(
      failFirstVideoRequest: true,
      failFirstVideoStatus: HttpStatus.gone,
    );
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
      cacheKey: 'gone-retry',
    );
    final response = await _get(localUrl, range: 'bytes=0-65535');

    expect(response.statusCode, HttpStatus.partialContent);
    expect(response.body, origin.bytes.sublist(0, 64 * 1024));
    expect(origin.videoRequestCount, greaterThanOrEqualTo(2));
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

  test('different media use independent upstream gates', () async {
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
      cacheKey: 'independent-a',
    );
    final secondUrl = await proxy.localUrlFor(
      origin.startUrl,
      headers: const <String, String>{'User-Agent': _cloud115UserAgent},
      cacheKey: 'independent-b',
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

  test('a stalled media does not block another media', () async {
    final origin = await _RangeOrigin.start(stallFirstVideoBody: true);
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

    final stalledUrl = await proxy.localUrlFor(
      origin.startUrl,
      headers: const <String, String>{'User-Agent': _cloud115UserAgent},
      cacheKey: 'stalled-media',
    );
    final stalledRequest = _get(
      stalledUrl,
      range: 'bytes=0-65535',
    ).catchError((_) => _RangeResponse(0, Uint8List(0)));
    await _waitUntil(() => origin.videoRequestCount >= 1);

    final otherUrl = await proxy.localUrlFor(
      origin.startUrl,
      headers: const <String, String>{'User-Agent': _cloud115UserAgent},
      cacheKey: 'other-media',
    );
    final other = await _get(
      otherUrl,
      range: 'bytes=131072-196607',
    ).timeout(const Duration(milliseconds: 1500));

    expect(other.statusCode, HttpStatus.partialContent);
    expect(other.body, origin.bytes.sublist(128 * 1024, 192 * 1024));

    proxy.release('stalled-media');
    await stalledRequest.timeout(const Duration(milliseconds: 1500));
  });

  test('release 取消残留会话并释放闸门给新媒体', () async {
    final origin = await _RangeOrigin.start(stallFirstVideoBody: true);
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

    final staleUrl = await proxy.localUrlFor(
      origin.startUrl,
      headers: const <String, String>{'User-Agent': _cloud115UserAgent},
      cacheKey: 'stale-media',
    );
    final staleRequest = _get(
      staleUrl,
      range: 'bytes=0-65535',
    ).catchError((_) => _RangeResponse(0, Uint8List(0)));
    await _waitUntil(() => origin.videoRequestCount >= 1);

    final freshUrl = await proxy.localUrlFor(
      origin.startUrl,
      headers: const <String, String>{'User-Agent': _cloud115UserAgent},
      cacheKey: 'fresh-media',
    );
    final freshRequest = _get(freshUrl, range: 'bytes=131072-196607');
    await Future<void>.delayed(const Duration(milliseconds: 100));

    proxy.release('stale-media');

    final fresh = await freshRequest.timeout(
      const Duration(milliseconds: 1500),
    );
    expect(fresh.statusCode, HttpStatus.partialContent);
    expect(fresh.body, origin.bytes.sublist(128 * 1024, 192 * 1024));

    final stale = await staleRequest.timeout(
      const Duration(milliseconds: 1500),
    );
    expect(stale.statusCode, isNot(HttpStatus.partialContent));
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

  test('disposed shared proxy is replaced by a fresh instance', () async {
    const policy = PlaybackProxyPolicy(
      providerKey: 'shared-restart-test',
      enabled: true,
    );
    final first = await LoopbackRangePlaybackProxy.shared(policy);
    addTearDown(first.dispose);

    await first.dispose();
    await Future<void>.delayed(Duration.zero);

    final second = await LoopbackRangePlaybackProxy.shared(policy);
    addTearDown(second.dispose);

    expect(identical(first, second), isFalse);
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
    required this.failFirstVideoStatus,
    required this.responseDelay,
    required this.stallFirstVideoBody,
    required this.stallFirstVideoAfterHeaders,
    required this.initialBodyBytes,
    required this.bodyChunkDelay,
  });

  final HttpServer _server;
  final Uint8List bytes;
  final bool failFirstVideoRequest;
  final int failFirstVideoStatus;
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
    int failFirstVideoStatus = HttpStatus.forbidden,
    Duration responseDelay = Duration.zero,
    bool stallFirstVideoBody = false,
    bool stallFirstVideoAfterHeaders = false,
    int initialBodyBytes = 0,
    Duration bodyChunkDelay = Duration.zero,
    Uint8List? bodyBytes,
  }) async {
    final bytes =
        bodyBytes ??
        Uint8List.fromList(
          List<int>.generate(2 * 1024 * 1024, (index) => index % 251),
        );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final origin = _RangeOrigin._(
      server,
      bytes,
      failFirstVideoRequest: failFirstVideoRequest,
      failFirstVideoStatus: failFirstVideoStatus,
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
    if (userAgent != _cloud115UserAgent) {
      response.statusCode = HttpStatus.forbidden;
      await response.close();
      return;
    }
    if (failFirstVideoRequest && videoRequestCount == 1) {
      response.statusCode = failFirstVideoStatus;
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
