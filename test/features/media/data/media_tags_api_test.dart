import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media/data/media_tag_dto.dart';
import 'package:sakuramedia/features/media/data/media_tags_api.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late MediaTagsApi api;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-10-31T12:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    api = MediaTagsApi(apiClient: apiClient);
  });

  tearDown(() => apiClient.dispose());

  test('getTags parses rules', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media-tags',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 3,
          'name': '4K',
          'include_terms': ['4k', '2160p'],
          'exclude_terms': ['sample'],
          'enabled': true,
          'media_count': 12,
          'created_at': '2026-10-30T01:02:03Z',
          'updated_at': '2026-10-31T01:02:03Z',
        },
      ],
    );

    final tags = await api.getTags();

    expect(tags.single.name, '4K');
    expect(tags.single.includeTerms, ['4k', '2160p']);
    expect(tags.single.excludeTerms, ['sample']);
    expect(tags.single.mediaCount, 12);
    expect(adapter.requests.single.uri.queryParameters, isEmpty);
  });

  test('create update and delete use media tag CRUD endpoints', () async {
    final payload = const MediaTagUpsertPayload(
      name: 'Chinese subtitles',
      includeTerms: ['中文字幕'],
      excludeTerms: ['machine'],
      enabled: false,
    );
    final body = <String, dynamic>{
      'id': 7,
      'name': 'Chinese subtitles',
      'include_terms': ['中文字幕'],
      'exclude_terms': ['machine'],
      'enabled': false,
      'media_count': 0,
      'created_at': '2026-10-30T01:02:03Z',
      'updated_at': '2026-10-30T01:02:03Z',
    };
    adapter.enqueueJson(method: 'POST', path: '/media-tags', body: body);

    final created = await api.createTag(payload);

    expect(created.id, 7);
    expect(adapter.requests.single.body, <String, dynamic>{
      'name': 'Chinese subtitles',
      'include_terms': ['中文字幕'],
      'exclude_terms': ['machine'],
      'enabled': false,
    });

    adapter.enqueueJson(method: 'PUT', path: '/media-tags/7', body: body);
    await api.updateTag(tagId: 7, payload: payload);
    expect(adapter.requests.last.body, <String, dynamic>{
      'name': 'Chinese subtitles',
      'include_terms': ['中文字幕'],
      'exclude_terms': ['machine'],
      'enabled': false,
    });

    adapter.enqueueJson(
      method: 'DELETE',
      path: '/media-tags/7',
      statusCode: 204,
      body: null,
    );
    await api.deleteTag(7);
    expect(adapter.hitCount('DELETE', '/media-tags/7'), 1);
  });

  test('preview sends optional release metadata and parses matches', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/media-tags/preview',
      body: <String, dynamic>{
        'matches': [
          {'tag_id': 1, 'name': '4K', 'matched_term': '2160p'},
        ],
      },
    );

    final matches = await api.preview(
      fileName: ' ABC-001.mkv ',
      releaseTitle: '  2160p  ',
      releaseDescription: '   ',
    );

    expect(matches.single.name, '4K');
    expect(matches.single.matchedTerm, '2160p');
    expect(adapter.requests.single.body, {
      'file_name': 'ABC-001.mkv',
      'release_title': '2160p',
    });
  });

  test('assignment endpoints parse manual lock state', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/42/tags',
      body: <String, dynamic>{
        'media_id': 42,
        'tags': [
          {'id': 1, 'name': '4K'},
        ],
        'is_media_tags_manually_managed': true,
      },
    );
    final current = await api.getAssignment(42);
    expect(current.mediaId, 42);
    expect(current.tags.single.name, '4K');
    expect(current.isManuallyManaged, isTrue);

    adapter.enqueueJson(
      method: 'PUT',
      path: '/media/42/tags',
      body: <String, dynamic>{
        'media_id': 42,
        'tags': [
          {'id': 2, 'name': 'Subtitles'},
        ],
        'is_media_tags_manually_managed': true,
      },
    );
    final saved = await api.setAssignment(mediaId: 42, tagIds: [2]);
    expect(saved.tags.single.id, 2);
    expect(adapter.requests.last.body, {
      'tag_ids': [2],
    });

    adapter.enqueueJson(
      method: 'POST',
      path: '/media/42/tags/reset',
      body: <String, dynamic>{
        'media_id': 42,
        'tags': <dynamic>[],
        'is_media_tags_manually_managed': false,
      },
    );
    final reset = await api.resetAssignmentToAuto(42);
    expect(reset.isManuallyManaged, isFalse);
  });
}
