import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/rankings/data/rankings_api.dart';
import 'package:sakuramedia/features/shared/data/movie_interaction_filter.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late ApiClient apiClient;
  late RankingsApi rankingsApi;
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
    rankingsApi = RankingsApi(apiClient: apiClient);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
  });

  tearDown(() {
    apiClient.dispose();
  });

  test('getRankingSources parses source list', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources',
      body: <Map<String, dynamic>>[
        <String, dynamic>{'source_key': 'javdb', 'name': 'JavDB'},
      ],
    );

    final sources = await rankingsApi.getRankingSources();

    expect(sources.length, 1);
    expect(sources[0].sourceKey, 'javdb');
    expect(sources[0].name, 'JavDB');
  });

  test('getRankingBoards requests source path and parses boards', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources/javdb/boards',
      statusCode: 200,
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'source_key': 'javdb',
          'board_key': 'censored',
          'name': '有码',
          'supported_periods': <String>['daily', 'weekly', 'monthly'],
          'default_period': 'daily',
        },
      ],
    );

    final boards = await rankingsApi.getRankingBoards(sourceKey: 'javdb');

    final request = adapter.requests.single;
    expect(request.path, '/ranking-sources/javdb/boards');
    expect(boards.single.sourceKey, 'javdb');
    expect(boards.single.boardKey, 'censored');
    expect(boards.single.name, '有码');
    expect(boards.single.supportedPeriods, ['daily', 'weekly', 'monthly']);
    expect(boards.single.defaultPeriod, 'daily');
  });

  test('getRankingItems sends period and paging query', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources/javdb/boards/censored/items',
      statusCode: 200,
      body: <String, dynamic>{
        'items': [
          <String, dynamic>{
            'rank': 1,
            'movie_number': 'ABP-001',
            'title': 'Movie A',
            'cover_image': <String, dynamic>{
              'id': 10,
              'origin': 'cover-large.jpg',
            },
            'thin_cover_image': <String, dynamic>{
              'id': 11,
              'origin': 'thin-large.jpg',
            },
            'release_date': '2024-10-01',
            'duration_minutes': 120,
            'heat': 1777,
            'is_subscribed': true,
            'can_play': true,
          },
        ],
        'page': 2,
        'page_size': 24,
        'total': 30,
        'synced_at': '2026-05-08T09:00:00',
      },
    );

    final page = await rankingsApi.getRankingItems(
      sourceKey: 'javdb',
      boardKey: 'censored',
      period: 'weekly',
      page: 2,
      pageSize: 24,
      sort: 'heat:desc',
      interaction: MovieInteractionFilter.initial
          .withRange(MovieInteractionMetric.heat, min: 100),
    );

    final request = adapter.requests.single;
    expect(request.uri.queryParameters['period'], 'weekly');
    expect(request.uri.queryParameters['page'], '2');
    expect(request.uri.queryParameters['page_size'], '24');
    expect(request.uri.queryParameters['sort'], 'heat:desc');
    expect(request.uri.queryParameters['heat_min'], '100');
    expect(page.items.single.rank, 1);
    expect(page.items.single.movieNumber, 'ABP-001');
    expect(page.items.single.coverImage?.origin, 'cover-large.jpg');
    expect(page.items.single.thinCoverImage?.origin, 'thin-large.jpg');
    expect(
      page.items.single.toMovieListItem().thinCoverImage?.origin,
      'thin-large.jpg',
    );
    expect(page.items.single.heat, 1777);
    expect(page.page, 2);
    expect(page.total, 30);
    expect(page.syncedAt, DateTime.parse('2026-05-08T09:00:00'));
  });

  test('rankings api converts backend errors to ApiException', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/ranking-sources',
      statusCode: 404,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'ranking_source_not_found',
          'message': 'source missing',
        },
      },
    );

    expect(
      () => rankingsApi.getRankingSources(),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.error?.code,
          'error.code',
          'ranking_source_not_found',
        ),
      ),
    );
  });
}
