import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/image_search/data/image_search_api.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late ApiClient apiClient;
  late ImageSearchApi imageSearchApi;
  late FakeHttpClientAdapter adapter;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-08T10:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    imageSearchApi = ImageSearchApi(apiClient: apiClient);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
  });

  tearDown(() {
    apiClient.dispose();
  });

  test('createSession sends multipart payload and parses first page', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/image-search/sessions',
      body: <String, dynamic>{
        'session_id': 'session-1',
        'status': 'ready',
        'page_size': 20,
        'next_cursor': 'cursor-1',
        'expires_at': '2026-03-08T10:10:00Z',
        'items': [
          <String, dynamic>{
            'thumbnail_id': 123,
            'media_id': 456,
            'movie_id': 789,
            'movie_number': 'ABC-001',
            'offset_seconds': 120,
            'score': 0.91,
            'image': <String, dynamic>{
              'id': 10,
              'origin': 'origin.webp',
              'small': 'small.webp',
              'medium': 'medium.webp',
              'large': 'large.webp',
            },
          },
        ],
      },
    );

    final session = await imageSearchApi.createSession(
      fileBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
      fileName: 'query.png',
      mimeType: 'image/png',
    );

    expect(session.sessionId, 'session-1');
    expect(session.status, 'ready');
    expect(session.pageSize, 20);
    expect(session.nextCursor, 'cursor-1');
    expect(session.items.single.movieNumber, 'ABC-001');
    expect(session.items.single.image.bestAvailableUrl, 'large.webp');

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/image-search/sessions');
    expect(request.body, isA<FormData>());
    final formData = request.body as FormData;
    final fields = Map<String, String>.fromEntries(formData.fields);
    expect(fields['page_size'], '20');
    expect(formData.files.single.key, 'file');
    expect(formData.files.single.value.filename, 'query.png');
    expect(formData.files.single.value.contentType?.mimeType, 'image/png');
  });

  test('createSession encodes include and exclude movie ids', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/image-search/sessions',
      body: <String, dynamic>{
        'session_id': 'session-1',
        'status': 'ready',
        'page_size': 20,
        'next_cursor': null,
        'expires_at': '2026-03-08T10:10:00Z',
        'items': const <Map<String, dynamic>>[],
      },
    );

    await imageSearchApi.createSession(
      fileBytes: Uint8List.fromList(const <int>[1, 2, 3]),
      fileName: 'query.webp',
      movieIds: const <int>[10, 20, 20],
      excludeMovieIds: const <int>[30, 40, 30],
    );

    final formData = adapter.requests.single.body as FormData;
    final fields = Map<String, String>.fromEntries(formData.fields);
    expect(fields['movie_ids'], '10,20');
    expect(fields['exclude_movie_ids'], '30,40');
  });

  test(
    'getNextResults sends cursor query parameter and parses response',
    () async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/image-search/sessions/session-1/results',
        body: <String, dynamic>{
          'session_id': 'session-1',
          'status': 'ready',
          'page_size': 20,
          'next_cursor': null,
          'expires_at': '2026-03-08T10:10:00Z',
          'items': [
            <String, dynamic>{
              'thumbnail_id': 124,
              'media_id': 457,
              'movie_id': 790,
              'movie_number': 'ABC-002',
              'offset_seconds': 240,
              'score': 0.87,
              'image': <String, dynamic>{
                'id': 11,
                'origin': 'origin-2.webp',
                'small': 'small-2.webp',
                'medium': 'medium-2.webp',
                'large': 'large-2.webp',
              },
            },
          ],
        },
      );

      final session = await imageSearchApi.getNextResults(
        sessionId: 'session-1',
        cursor: 'cursor-1',
      );

      expect(session.items.single.movieNumber, 'ABC-002');
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/image-search/sessions/session-1/results');
      expect(request.uri.queryParameters['cursor'], 'cursor-1');
    },
  );

  test(
    'createSession normalizes empty and whitespace next_cursor to null',
    () async {
      adapter.enqueueJson(
        method: 'POST',
        path: '/image-search/sessions',
        body: <String, dynamic>{
          'session_id': 'session-empty-cursor',
          'status': 'ready',
          'page_size': 20,
          'next_cursor': '',
          'expires_at': '2026-03-08T10:10:00Z',
          'items': const <Map<String, dynamic>>[],
        },
      );
      adapter.enqueueJson(
        method: 'POST',
        path: '/image-search/sessions',
        body: <String, dynamic>{
          'session_id': 'session-blank-cursor',
          'status': 'ready',
          'page_size': 20,
          'next_cursor': '   ',
          'expires_at': '2026-03-08T10:10:00Z',
          'items': const <Map<String, dynamic>>[],
        },
      );

      final emptyCursorSession = await imageSearchApi.createSession(
        fileBytes: Uint8List.fromList(const <int>[1, 2]),
        fileName: 'query-empty.png',
      );
      final blankCursorSession = await imageSearchApi.createSession(
        fileBytes: Uint8List.fromList(const <int>[3, 4]),
        fileName: 'query-blank.png',
      );

      expect(emptyCursorSession.nextCursor, isNull);
      expect(blankCursorSession.nextCursor, isNull);
    },
  );

  test('createSession converts backend error to ApiException', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/image-search/sessions',
      statusCode: 400,
      body: <String, dynamic>{
        'error': <String, dynamic>{'code': 'invalid_image', 'message': '图片无效'},
      },
    );

    expect(
      () => imageSearchApi.createSession(
        fileBytes: Uint8List.fromList(const <int>[1, 2]),
        fileName: 'broken.png',
      ),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.error?.code,
          'error.code',
          'invalid_image',
        ),
      ),
    );
  });
}
