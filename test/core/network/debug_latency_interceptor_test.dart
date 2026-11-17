import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/debug_latency_interceptor.dart';

import '../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const delay = Duration(milliseconds: 300);
  const noDelayBudget = Duration(milliseconds: 250);

  late Dio dio;
  late FakeHttpClientAdapter adapter;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    adapter = FakeHttpClientAdapter();
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(DebugLatencyInterceptor(min: delay, max: delay));
  });

  test('delays json GET requests', () async {
    adapter.enqueueJson(method: 'GET', path: '/movies', body: {'total': 1});

    final stopwatch = Stopwatch()..start();
    final response = await dio.get<Map<String, dynamic>>('/movies');
    stopwatch.stop();

    expect(response.data, {'total': 1});
    expect(stopwatch.elapsed, greaterThanOrEqualTo(delay));
  });

  test('does not delay write requests', () async {
    adapter.enqueueJson(method: 'POST', path: '/movies', body: {'id': 1});

    final stopwatch = Stopwatch()..start();
    final response = await dio.post<Map<String, dynamic>>('/movies');
    stopwatch.stop();

    expect(response.data, {'id': 1});
    expect(stopwatch.elapsed, lessThan(noDelayBudget));
  });

  test('does not delay stream responses', () async {
    adapter.enqueueSse(
      method: 'GET',
      path: '/events',
      chunks: const ['data: {"a":1}\n\n'],
    );

    final stopwatch = Stopwatch()..start();
    await dio.get<ResponseBody>(
      '/events',
      options: Options(responseType: ResponseType.stream),
    );
    stopwatch.stop();

    expect(stopwatch.elapsed, lessThan(noDelayBudget));
  });

  test('does not delay byte download responses', () async {
    adapter.enqueueBytes(
      method: 'GET',
      path: '/files/1',
      body: Uint8List.fromList(const <int>[1, 2, 3]),
    );

    final stopwatch = Stopwatch()..start();
    await dio.get<List<int>>(
      '/files/1',
      options: Options(responseType: ResponseType.bytes),
    );
    stopwatch.stop();

    expect(stopwatch.elapsed, lessThan(noDelayBudget));
  });
}
