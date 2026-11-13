import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/media/playback_proxy_policy.dart';
import 'package:sakuramedia/core/media/playback_range_proxy.dart';

const _cloud115UserAgent = 'Mozilla/5.0; Darwin/10.0; UDown/39.1.0';

void main() {
  late Directory cacheDirectory;
  HttpOverrides? previousHttpOverrides;

  setUpAll(() {
    previousHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
  });

  tearDownAll(() {
    HttpOverrides.global = previousHttpOverrides;
  });

  setUp(() async {
    cacheDirectory = await Directory.systemTemp.createTemp(
      'cloud115_proxy_test',
    );
  });

  tearDown(() async {
    if (await cacheDirectory.exists()) {
      await cacheDirectory.delete(recursive: true);
    }
  });

  test('follows redirect, forwards UA and retries one 403', () async {
    final origin = await _RangeOrigin.start(failFirstVideoRequest: true);
    final proxy = await LoopbackRangePlaybackProxy.create(
      policy: cloud115PlaybackProxyPolicy.copyWith(
        maxCacheBytes: 2 * 1024 * 1024,
        maxEntryBytes: 1024 * 1024,
        chunkSize: 64 * 1024,
      ),
      cacheDirectory: cacheDirectory,
      upstream: BoundedConcurrencyUpstream(
        maxConcurrentRequests: 1,
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
    expect(origin.videoRequestCount, greaterThanOrEqualTo(3));
    expect(origin.userAgents, everyElement(_cloud115UserAgent));
  });

  test('serializes different seek ranges to one upstream request', () async {
    final origin = await _RangeOrigin.start(
      responseDelay: const Duration(milliseconds: 80),
    );
    final proxy = await LoopbackRangePlaybackProxy.create(
      policy: cloud115PlaybackProxyPolicy.copyWith(
        maxCacheBytes: 2 * 1024 * 1024,
        maxEntryBytes: 1024 * 1024,
        chunkSize: 64 * 1024,
      ),
      cacheDirectory: cacheDirectory,
      upstream: BoundedConcurrencyUpstream(
        maxConcurrentRequests: 1,
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
      cacheKey: 'serialized-seeks',
    );
    final responses = await Future.wait([
      _get(localUrl, range: 'bytes=0-65535'),
      _get(localUrl, range: 'bytes=131072-196607'),
    ]);

    expect(
      responses.map((response) => response.statusCode),
      everyElement(HttpStatus.partialContent),
    );
    expect(responses[0].body, origin.bytes.sublist(0, 64 * 1024));
    expect(responses[1].body, origin.bytes.sublist(128 * 1024, 192 * 1024));
    expect(origin.maxActiveVideoRequests, 1);
  });

  test('policy concurrency can allow more than one upstream request', () async {
    final origin = await _RangeOrigin.start(
      responseDelay: const Duration(milliseconds: 80),
    );
    final proxy = await LoopbackRangePlaybackProxy.create(
      policy: cloud115PlaybackProxyPolicy.copyWith(
        maxConcurrentUpstreamRequests: 2,
        maxCacheBytes: 2 * 1024 * 1024,
        maxEntryBytes: 1024 * 1024,
        chunkSize: 64 * 1024,
      ),
      cacheDirectory: cacheDirectory,
      upstream: BoundedConcurrencyUpstream(
        maxConcurrentRequests: 2,
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
      cacheKey: 'concurrency-two',
    );
    final responses = await Future.wait([
      _get(localUrl, range: 'bytes=0-65535'),
      _get(localUrl, range: 'bytes=131072-196607'),
    ]);

    expect(
      responses.map((response) => response.statusCode),
      everyElement(HttpStatus.partialContent),
    );
    expect(origin.maxActiveVideoRequests, 2);
  });

  test('times out a stalled response body and releases the queue', () async {
    final origin = await _RangeOrigin.start(stallVideoBody: true);
    final proxy = await LoopbackRangePlaybackProxy.create(
      policy: cloud115PlaybackProxyPolicy.copyWith(
        maxCacheBytes: 2 * 1024 * 1024,
        maxEntryBytes: 1024 * 1024,
        chunkSize: 64 * 1024,
      ),
      cacheDirectory: cacheDirectory,
      upstream: BoundedConcurrencyUpstream(
        maxConcurrentRequests: 1,
        timeout: const Duration(milliseconds: 100),
        retryDelay: const Duration(milliseconds: 10),
        cooldown: Duration.zero,
        maxAttempts: 1,
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

    await expectLater(
      _get(localUrl, range: 'bytes=0-65535'),
      throwsA(isA<HttpException>()),
    );

    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
    await _waitUntilAsync(
      () async => await _hasEstablishedConnectionTo(origin.port) == false,
    );
    final nextStopwatch = Stopwatch()..start();
    final next = await _get(localUrl, range: 'bytes=65536-131071');
    expect(nextStopwatch.elapsed, lessThan(const Duration(seconds: 1)));
    expect(next.statusCode, HttpStatus.partialContent);
    expect(next.body, origin.bytes.sublist(64 * 1024, 128 * 1024));
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

Future<void> _waitUntilAsync(Future<bool> Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!await condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(await condition(), isTrue);
}

Future<bool> _hasEstablishedConnectionTo(int port) async {
  final process = await Process.run('/usr/sbin/lsof', <String>[
    '-nP',
    '-a',
    '-p',
    '$pid',
    '-iTCP',
    '-sTCP:ESTABLISHED',
    '-Fn',
  ]);
  for (final line in const LineSplitter().convert(process.stdout as String)) {
    if (line.startsWith('n') && line.contains(':$port')) {
      return true;
    }
  }
  return false;
}

class _RangeOrigin {
  _RangeOrigin._(
    this._server,
    this.bytes, {
    required this.failFirstVideoRequest,
    required this.responseDelay,
    required this.stallVideoBody,
  });

  final HttpServer _server;
  final Uint8List bytes;
  final bool failFirstVideoRequest;
  final Duration responseDelay;
  final bool stallVideoBody;
  final List<String> userAgents = <String>[];
  int videoRequestCount = 0;
  int activeVideoRequests = 0;
  int maxActiveVideoRequests = 0;
  int get port => _server.port;

  String get startUrl => 'http://127.0.0.1:${_server.port}/start';

  static Future<_RangeOrigin> start({
    bool failFirstVideoRequest = false,
    Duration responseDelay = Duration.zero,
    bool stallVideoBody = false,
  }) async {
    final bytes = Uint8List.fromList(
      List<int>.generate(256 * 1024, (index) => index % 251),
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final origin = _RangeOrigin._(
      server,
      bytes,
      failFirstVideoRequest: failFirstVideoRequest,
      responseDelay: responseDelay,
      stallVideoBody: stallVideoBody,
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
      final range = request.headers.value(HttpHeaders.rangeHeader);
      final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range ?? '');
      final start = match == null ? 0 : int.parse(match.group(1)!);
      final endText = match?.group(2) ?? '';
      final end = endText.isEmpty ? bytes.length - 1 : int.parse(endText);
      final slice = bytes.sublist(start, end + 1);
      if (stallVideoBody && videoRequestCount == 2) {
        response
          ..statusCode = HttpStatus.partialContent
          ..headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes $start-$end/${bytes.length}',
          )
          ..headers.contentLength = slice.length
          ..headers.contentType = ContentType('video', 'mp4')
          ..bufferOutput = false;
        await response.flush();
        for (var attempt = 0; attempt < 10; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          try {
            response.add(<int>[0]);
            await response.flush();
          } catch (_) {
            break;
          }
        }
        return;
      }
      response
        ..statusCode = HttpStatus.partialContent
        ..headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/${bytes.length}',
        )
        ..headers.contentLength = slice.length
        ..headers.contentType = ContentType('video', 'mp4')
        ..add(slice);
      await response.close();
    } finally {
      activeVideoRequests--;
    }
  }
}
