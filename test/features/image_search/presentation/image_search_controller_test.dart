import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/image_search/data/image_search_api.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_controller.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;
  late ImageSearchController controller;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
    controller = ImageSearchController(
      imageSearchApi: ImageSearchApi(apiClient: bundle.apiClient),
      actorsApi: bundle.actorsApi,
    );
  });

  tearDown(() {
    bundle.dispose();
    controller.dispose();
  });

  test('search populates items and next cursor', () async {
    bundle.adapter.enqueueJson(
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
              'origin': '/thumb-1.webp',
              'small': '/thumb-1.webp',
              'medium': '/thumb-1.webp',
              'large': '/thumb-1.webp',
            },
          },
        ],
      },
    );

    controller.setSource(
      fileBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
      fileName: 'query.png',
      mimeType: 'image/png',
    );
    await controller.search();

    expect(bundle.adapter.hitCount('POST', '/image-search/sessions'), 1);
    expect(controller.errorMessage, isNull);
    expect(controller.items.map((item) => item.thumbnailId), contains(123));
    expect(controller.nextCursor, 'cursor-1');
  });

  test(
    'loadMore stops pagination when backend returns repeated next cursor',
    () async {
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/image-search/sessions',
        body: <String, dynamic>{
          'session_id': 'session-1',
          'status': 'ready',
          'page_size': 20,
          'next_cursor': 'cursor-1',
          'expires_at': '2026-03-08T10:10:00Z',
          'items': const <Map<String, dynamic>>[],
        },
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/image-search/sessions/session-1/results',
        body: <String, dynamic>{
          'session_id': 'session-1',
          'status': 'ready',
          'page_size': 20,
          'next_cursor': 'cursor-1',
          'expires_at': '2026-03-08T10:10:00Z',
          'items': const <Map<String, dynamic>>[],
        },
      );

      controller.setSource(
        fileBytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
        fileName: 'query.png',
        mimeType: 'image/png',
      );
      await controller.search();
      await controller.loadMore();
      await controller.loadMore();

      expect(
        bundle.adapter.hitCount(
          'GET',
          '/image-search/sessions/session-1/results',
        ),
        1,
      );
      expect(controller.nextCursor, isNull);
      expect(controller.hasMore, isFalse);
    },
  );
}
