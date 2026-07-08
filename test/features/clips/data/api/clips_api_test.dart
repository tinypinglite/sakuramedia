import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/clips/data/api/clips_api.dart';

import '../../../../support/fake_http_client_adapter.dart';

Map<String, dynamic> _clipJson({int clipId = 12}) => <String, dynamic>{
  'clip_id': clipId,
  'media_id': 34,
  'movie_number': 'ABC-001',
  'start_offset_seconds': 10,
  'end_offset_seconds': 30,
  'title': '精彩片段',
  'duration_seconds': 20,
  'file_size_bytes': 1048576,
  'cover_image': <String, dynamic>{
    'id': 1,
    'origin': '/clips/12-origin.webp',
    'small': '/clips/12-small.webp',
    'medium': '/clips/12-medium.webp',
    'large': '/clips/12-large.webp',
  },
  'stream_url': '/media-clips/12/stream?expires=1&signature=abc',
  'created_at': '2026-06-13T10:00:00Z',
};

void main() {
  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late ClipsApi clipsApi;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    clipsApi = ClipsApi(apiClient: apiClient);
  });

  tearDown(() {
    apiClient.dispose();
  });

  test('createClip maps POST /media/{media_id}/clips', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/media/34/clips',
      statusCode: 201,
      body: _clipJson(),
    );

    final clip = await clipsApi.createClip(
      mediaId: 34,
      startThumbnailId: 100,
      endThumbnailId: 130,
      title: '精彩片段',
    );

    expect(clip.clipId, 12);
    expect(clip.mediaId, 34);
    expect(clip.movieNumber, 'ABC-001');
    expect(clip.durationSeconds, 20);
    expect(clip.streamUrl, '/media-clips/12/stream?expires=1&signature=abc');
    expect(adapter.hitCount('POST', '/media/34/clips'), 1);
    expect(adapter.requests.single.body, <String, dynamic>{
      'start_thumbnail_id': 100,
      'end_thumbnail_id': 130,
      'title': '精彩片段',
    });
  });

  test('getMyClips maps GET /media-clips with pagination', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-clips',
      body: <String, dynamic>{
        'items': [_clipJson()],
        'page': 1,
        'page_size': 24,
        'total': 1,
      },
    );

    final page = await clipsApi.getMyClips(page: 1, pageSize: 24);

    expect(page.items, hasLength(1));
    expect(page.items.single.clipId, 12);
    expect(page.items.single.coverImage?.bestAvailableUrl, '/clips/12-large.webp');
    expect(page.total, 1);
    expect(adapter.requests.single.uri.queryParameters, <String, String>{
      'page': '1',
      'page_size': '24',
      'sort': 'created_at:desc',
    });
  });

  test('getClipsByMedia maps GET /media/{media_id}/clips', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/34/clips',
      body: <Map<String, dynamic>>[_clipJson(), _clipJson(clipId: 13)],
    );

    final clips = await clipsApi.getClipsByMedia(mediaId: 34);

    expect(clips, hasLength(2));
    expect(clips.first.clipId, 12);
    expect(clips.last.clipId, 13);
  });

  test('getClipDetail maps GET /media-clips/{clip_id} with detail fields', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-clips/12',
      body: <String, dynamic>{
        ..._clipJson(),
        'preview_frames': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 2,
            'origin': '/clips/12-f0.webp',
            'small': '/clips/12-f0-s.webp',
            'medium': '/clips/12-f0-m.webp',
            'large': '/clips/12-f0-l.webp',
          },
          <String, dynamic>{
            'id': 3,
            'origin': '/clips/12-f1.webp',
            'small': '/clips/12-f1-s.webp',
            'medium': '/clips/12-f1-m.webp',
            'large': '/clips/12-f1-l.webp',
          },
        ],
        'collections': <Map<String, dynamic>>[
          <String, dynamic>{'id': 7, 'name': '精选合集'},
        ],
      },
    );

    final clip = await clipsApi.getClipDetail(clipId: 12);

    expect(clip.clipId, 12);
    expect(clip.previewFrames, hasLength(2));
    expect(clip.previewFrames.first.bestAvailableUrl, '/clips/12-f0-l.webp');
    expect(clip.collections, hasLength(1));
    expect(clip.collections.single.id, 7);
    expect(clip.collections.single.name, '精选合集');
    expect(adapter.hitCount('GET', '/media-clips/12'), 1);
  });

  test('updateClipTitle maps PATCH /media-clips/{clip_id}', () async {
    adapter.enqueueJson(
      method: 'PATCH',
      path: '/media-clips/12',
      body: _clipJson(),
    );

    final clip = await clipsApi.updateClipTitle(clipId: 12, title: ' 新标题 ');

    expect(clip.clipId, 12);
    expect(adapter.requests.single.body, <String, dynamic>{'title': '新标题'});
  });

  test('deleteClip maps DELETE /media-clips/{clip_id}', () async {
    adapter.enqueueJson(
      method: 'DELETE',
      path: '/media-clips/12',
      statusCode: 204,
    );

    await clipsApi.deleteClip(clipId: 12);

    expect(adapter.hitCount('DELETE', '/media-clips/12'), 1);
  });

  test('getClipThumbnails maps GET /media-clips/{clip_id}/thumbnails', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-clips/12/thumbnails',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'clip_id': 12,
          'thumbnail_id': 201,
          'offset_seconds': 0,
          'image': <String, dynamic>{
            'id': 2,
            'origin': '/clips/12-f0.webp',
            'small': '/clips/12-f0-s.webp',
            'medium': '/clips/12-f0-m.webp',
            'large': '/clips/12-f0-l.webp',
          },
        },
        <String, dynamic>{
          'clip_id': 12,
          'thumbnail_id': 202,
          'offset_seconds': 10,
          'image': <String, dynamic>{
            'id': 3,
            'origin': '/clips/12-f1.webp',
            'small': '/clips/12-f1-s.webp',
            'medium': '/clips/12-f1-m.webp',
            'large': '/clips/12-f1-l.webp',
          },
        },
      ],
    );

    final thumbnails = await clipsApi.getClipThumbnails(clipId: 12);

    expect(thumbnails, hasLength(2));
    expect(thumbnails.first.thumbnailId, 201);
    expect(thumbnails.first.offsetSeconds, 0);
    expect(thumbnails.last.offsetSeconds, 10);
    expect(thumbnails.last.image.bestAvailableUrl, '/clips/12-f1-l.webp');
    expect(adapter.hitCount('GET', '/media-clips/12/thumbnails'), 1);
  });
}
