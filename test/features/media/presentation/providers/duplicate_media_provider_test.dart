import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/duplicate_media_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_mutation_events_provider.dart';

import '../../../../support/fake_http_client_adapter.dart';

void main() {
  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late ProviderContainer container;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-05-13T12:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(sessionStore),
        mediaApiProvider.overrideWithValue(MediaApi(apiClient: apiClient)),
      ],
      retry: (_, __) => null,
    );
  });

  tearDown(() {
    container.dispose();
    apiClient.dispose();
    sessionStore.dispose();
  });

  test('loads duplicate groups and appends another page', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/duplicates',
      body: _duplicatePage(
        page: 1,
        total: 2,
        groups: [
          _duplicateGroup(1, [1, 2]),
        ],
      ),
    );
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/duplicates',
      body: _duplicatePage(
        page: 2,
        total: 2,
        groups: [
          _duplicateGroup(2, [3, 4]),
        ],
      ),
    );

    final provider = duplicateMediaProvider(MediaListItemKind.jav);
    await container.read(provider.future);
    await container.read(provider.notifier).loadMore();

    final state = container.read(provider).requireValue;
    expect(state.items.map((group) => group.mediaItems.first.id), [1, 3]);
    expect(state.total, 2);
    expect(adapter.requests[0].uri.queryParameters['kind'], 'jav');
    expect(adapter.requests[1].uri.queryParameters['page'], '2');
  });

  test(
    'deleting an item shrinks its group and removes a no-longer-duplicate group',
    () async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/media/duplicates',
        body: _duplicatePage(
          page: 1,
          total: 1,
          groups: [
            _duplicateGroup(1, [1, 2, 3]),
          ],
        ),
      );
      adapter.enqueueJson(method: 'DELETE', path: '/media/2', statusCode: 204);

      final provider = duplicateMediaProvider(MediaListItemKind.jav);
      await container.read(provider.future);
      final notifier = container.read(provider.notifier);

      final shrinkRefresh = Completer<ResponseBody>();
      final shrinkStarted = Completer<void>();
      adapter.enqueueResponder(
        method: 'GET',
        path: '/media/duplicates',
        responder: (_, __) {
          shrinkStarted.complete();
          return shrinkRefresh.future;
        },
      );
      final shrink = notifier.deleteDuplicateMedia(mediaId: 2);
      await shrinkStarted.future;
      var state = container.read(provider).requireValue;
      expect(container.read(provider).isLoading, isFalse);
      expect(state.items.single.mediaCount, 2);
      expect(state.items.single.mediaItems.map((item) => item.id), [1, 3]);
      shrinkRefresh.complete(
        _responseBody(
          _duplicatePage(
            page: 1,
            total: 1,
            groups: [
              _duplicateGroup(1, [1, 3]),
            ],
          ),
        ),
      );
      await shrink;

      adapter.enqueueJson(method: 'DELETE', path: '/media/1', statusCode: 204);
      final removeRefresh = Completer<ResponseBody>();
      final removeStarted = Completer<void>();
      adapter.enqueueResponder(
        method: 'GET',
        path: '/media/duplicates',
        responder: (_, __) {
          removeStarted.complete();
          return removeRefresh.future;
        },
      );
      final remove = notifier.deleteDuplicateMedia(mediaId: 1);
      await removeStarted.future;
      state = container.read(provider).requireValue;
      expect(state.items, isEmpty);
      expect(state.total, 0);
      removeRefresh.complete(
        _responseBody(_duplicatePage(page: 1, total: 0, groups: const [])),
      );
      await remove;
      expect(adapter.hitCount('DELETE', '/media/2'), 1);
      expect(adapter.hitCount('DELETE', '/media/1'), 1);
    },
  );

  test('deleting a PornBox duplicate broadcasts deleted video', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/duplicates',
      body: _duplicatePage(
        page: 1,
        total: 1,
        groups: [
          _videoDuplicateGroup([11, 22], [101, 202]),
        ],
      ),
    );
    adapter.enqueueJson(method: 'DELETE', path: '/media/11', statusCode: 204);
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/duplicates',
      body: _duplicatePage(page: 1, total: 0, groups: const []),
    );

    final events = <VideoMutationChange>[];
    container.listen(videoMutationEventsProvider, (_, next) {
      final change = next.value;
      if (change != null) events.add(change);
    });

    final provider = duplicateMediaProvider(MediaListItemKind.video);
    await container.read(provider.future);
    await container.read(provider.notifier).deleteDuplicateMedia(mediaId: 11);

    expect(events, hasLength(1));
    expect(events.single.kind, VideoMutationKind.deleted);
    expect(events.single.videoId, 101);
  });
}

ResponseBody _responseBody(Map<String, dynamic> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

Map<String, dynamic> _duplicatePage({
  required int page,
  required int total,
  required List<Map<String, dynamic>> groups,
}) {
  return <String, dynamic>{
    'items': groups,
    'page': page,
    'page_size': 20,
    'total': total,
  };
}

Map<String, dynamic> _duplicateGroup(int groupId, List<int> mediaIds) {
  return <String, dynamic>{
    'kind': 'jav',
    'media_count': mediaIds.length,
    'media_items': [
      for (final mediaId in mediaIds) _mediaItem(mediaId, groupId),
    ],
  };
}

Map<String, dynamic> _videoDuplicateGroup(
  List<int> mediaIds,
  List<int> videoItemIds,
) {
  return <String, dynamic>{
    'kind': 'video',
    'media_count': mediaIds.length,
    'media_items': [
      for (var i = 0; i < mediaIds.length; i++)
        <String, dynamic>{
          ..._mediaItem(mediaIds[i], 1),
          'kind': 'video',
          'movie_number': null,
          'video_item_id': videoItemIds[i],
        },
    ],
  };
}

Map<String, dynamic> _mediaItem(int id, int groupId) {
  return <String, dynamic>{
    'id': id,
    'kind': 'jav',
    'movie_number': 'DUP-$groupId',
    'video_item_id': null,
    'title': 'Duplicate $id',
    'cover_image': null,
    'thin_cover_image': null,
    'library_id': 1,
    'library_name': 'Main',
    'file_name': 'duplicate-$id.mp4',
    'file_size_bytes': 100,
    'duration_seconds': 60,
    'resolution': '1920x1080',
    'valid': true,
    'thumbnail_generation_state': 'succeeded',
    'thumbnail_last_error_code': null,
    'heat': 100,
    'created_at': '2026-03-12T10:00:00Z',
    'updated_at': '2026-03-12T10:00:00Z',
  };
}
