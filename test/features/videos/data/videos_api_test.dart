import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/videos/data/video_item_detail_dto.dart';
import 'package:sakuramedia/features/videos/data/videos_api.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late ApiClient apiClient;
  late VideosApi videosApi;
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
    videosApi = VideosApi(apiClient: apiClient);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
  });

  tearDown(() {
    apiClient.dispose();
  });

  test('getVideos 编码 query/sort 并解析分页', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/videos',
      body: <String, dynamic>{
        'items': <dynamic>[
          <String, dynamic>{
            'id': 1,
            'title': '视频一',
            'summary': '',
            'cover_image': null,
            'release_date': '2026-01-01T00:00:00',
            'media_count': 2,
            'can_play': true,
            'created_at': '2026-01-02T03:04:05',
            'updated_at': '2026-01-02T03:04:05',
          },
        ],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
    );

    final result = await videosApi.getVideos(
      query: '关键词',
      sort: 'created_at:desc',
    );

    expect(result.total, 1);
    expect(result.items, hasLength(1));
    expect(result.items.first.title, '视频一');
    expect(result.items.first.mediaCount, 2);
    expect(result.items.first.canPlay, isTrue);

    final recorded = adapter.requests.single;
    expect(recorded.uri.queryParameters['query'], '关键词');
    expect(recorded.uri.queryParameters['sort'], 'created_at:desc');
    // 后端已移除 videos 域标签/人物筛选，不应再下发这两个 key。
    expect(recorded.uri.queryParameters.containsKey('tag_id'), isFalse);
    expect(recorded.uri.queryParameters.containsKey('person_id'), isFalse);
  });

  test('getVideoDetail 复用 MovieMediaItemDto 解析 media_items（含进度与时刻）',
      () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/videos/7',
      body: <String, dynamic>{
        'id': 7,
        'title': '详情视频',
        'summary': '简介',
        'cover_image': null,
        'release_date': null,
        'media_count': 1,
        'can_play': true,
        'created_at': '2026-01-02T03:04:05',
        'updated_at': '2026-01-02T03:04:05',
        'media_items': <dynamic>[
          <String, dynamic>{
            'media_id': 31,
            'library_id': 1,
            'play_url': '/files/videos/7/clip.mp4?sig=abc',
            'path': '/data/videos/7/clip.mp4',
            'storage_mode': 'local',
            'resolution': '1080p',
            'file_size_bytes': 1048576,
            'duration_seconds': 600,
            'special_tags': '',
            'valid': true,
            'progress': <String, dynamic>{
              'last_position_seconds': 120,
              'last_watched_at': '2026-01-03T10:00:00',
            },
            'points': <dynamic>[
              <String, dynamic>{
                'point_id': 41,
                'thumbnail_id': 51,
                'offset_seconds': 90,
                'image': null,
              },
            ],
            'video_info': null,
          },
        ],
      },
    );

    final detail = await videosApi.getVideoDetail(videoId: 7);

    expect(detail, isA<VideoItemDetailDto>());
    expect(detail.id, 7);
    expect(detail.mediaItems, hasLength(1));

    final media = detail.mediaItems.single;
    expect(media.mediaId, 31);
    expect(media.playUrl, '/files/videos/7/clip.mp4?sig=abc');
    expect(media.hasPlayableUrl, isTrue);
    expect(media.durationSeconds, 600);
    expect(media.progress?.lastPositionSeconds, 120);
    expect(media.points.single.offsetSeconds, 90);
  });

  test('updateVideo 仅下发 payload 中非空字段', () async {
    adapter.enqueueJson(
      method: 'PATCH',
      path: '/videos/9',
      body: <String, dynamic>{
        'id': 9,
        'title': '改后标题',
        'summary': '',
        'media_count': 0,
        'can_play': false,
        'created_at': '2026-01-02T03:04:05',
        'updated_at': '2026-01-02T03:04:05',
        'media_items': <dynamic>[],
      },
    );

    await videosApi.updateVideo(
      videoId: 9,
      payload: const VideoItemUpdatePayload(title: '改后标题'),
    );

    final body = adapter.requests.single.body as Map<String, dynamic>;
    expect(body.containsKey('title'), isTrue);
    expect(body['title'], '改后标题');
    // 未传的字段不应出现，避免误清空。
    expect(body.containsKey('summary'), isFalse);
    expect(body.containsKey('release_date'), isFalse);
    expect(body.containsKey('tag_ids'), isFalse);
    expect(body.containsKey('person_ids'), isFalse);
  });
}
