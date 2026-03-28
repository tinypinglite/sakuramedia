import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_review_dto.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/data/parsed_movie_number_dto.dart';
import 'package:sakuramedia/features/movies/presentation/movie_filter_state.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late ApiClient apiClient;
  late MoviesApi moviesApi;
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
    moviesApi = MoviesApi(apiClient: apiClient);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
  });

  tearDown(() {
    apiClient.dispose();
  });

  test('getMovies sends movie library filters and parses response', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      statusCode: 200,
      body: <String, dynamic>{
        'items': [
          <String, dynamic>{
            'javdb_id': 'MovieA1',
            'movie_number': 'ABC-001',
            'title': 'Movie 1',
            'cover_image': null,
            'release_date': '2024-01-02',
            'duration_minutes': 120,
            'is_subscribed': true,
            'can_play': true,
          },
        ],
        'page': 1,
        'page_size': 24,
        'total': 1,
      },
    );

    final page = await moviesApi.getMovies(
      status: MovieStatusFilter.subscribed,
      collectionType: MovieCollectionTypeFilter.single,
      sort: 'release_date:desc',
      page: 1,
      pageSize: 24,
    );

    final request = adapter.requests.single;
    expect(request.uri.queryParameters['status'], 'subscribed');
    expect(request.uri.queryParameters['collection_type'], 'single');
    expect(request.uri.queryParameters['sort'], 'release_date:desc');
    expect(request.uri.queryParameters['actor_id'], isNull);
    expect(request.uri.queryParameters['page'], '1');
    expect(request.uri.queryParameters['page_size'], '24');
    expect(page.items.single.movieNumber, 'ABC-001');
  });

  test('getMovies sends actor_id when actor filter is provided', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      statusCode: 200,
      body: <String, dynamic>{
        'items': const <Map<String, dynamic>>[],
        'page': 1,
        'page_size': 24,
        'total': 0,
      },
    );

    await moviesApi.getMovies(actorId: 7, page: 1, pageSize: 24);

    final request = adapter.requests.single;
    expect(request.uri.queryParameters['actor_id'], '7');
  });

  test('getMovies omits optional filters when not provided', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      statusCode: 200,
      body: <String, dynamic>{
        'items': const <Map<String, dynamic>>[],
        'page': 1,
        'page_size': 20,
        'total': 0,
      },
    );

    await moviesApi.getMovies(page: 1, pageSize: 20);

    final request = adapter.requests.single;
    expect(request.uri.queryParameters.containsKey('status'), isFalse);
    expect(request.uri.queryParameters.containsKey('collection_type'), isFalse);
    expect(request.uri.queryParameters.containsKey('sort'), isFalse);
  });

  test('getMovies converts backend error to ApiException', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
      },
    );

    expect(
      () => moviesApi.getMovies(
        status: MovieStatusFilter.playable,
        collectionType: MovieCollectionTypeFilter.all,
        sort: 'added_at:desc',
      ),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.error?.code,
          'error.code',
          'server_error',
        ),
      ),
    );
  });

  test(
    'parseMovieNumber sends query body and parses success response',
    () async {
      adapter.enqueueJson(
        method: 'POST',
        path: '/movies/search/parse-number',
        statusCode: 200,
        body: <String, dynamic>{
          'query': 'abp123',
          'parsed': true,
          'movie_number': 'ABP-123',
          'reason': null,
        },
      );

      final result = await moviesApi.parseMovieNumber(query: 'abp123');

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/movies/search/parse-number');
      expect(request.body, <String, dynamic>{'query': 'abp123'});
      expect(
        result,
        const ParsedMovieNumberDto(
          query: 'abp123',
          parsed: true,
          movieNumber: 'ABP-123',
          reason: null,
        ),
      );
    },
  );

  test('parseMovieNumber parses failed response', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/movies/search/parse-number',
      statusCode: 200,
      body: <String, dynamic>{
        'query': 'mikami',
        'parsed': false,
        'movie_number': null,
        'reason': 'movie_number_not_found',
      },
    );

    final result = await moviesApi.parseMovieNumber(query: 'mikami');

    expect(result.parsed, isFalse);
    expect(result.movieNumber, isNull);
    expect(result.reason, 'movie_number_not_found');
  });

  test('parseMovieNumber converts backend error to ApiException', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/movies/search/parse-number',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
      },
    );

    expect(
      () => moviesApi.parseMovieNumber(query: 'abp123'),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.error?.code,
          'error.code',
          'server_error',
        ),
      ),
    );
  });

  test('searchLocalMovies sends movie number query and parses list', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/movies/search/local',
      statusCode: 200,
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'javdb_id': 'MovieA1',
          'movie_number': 'ABP-123',
          'title': 'Movie 1',
          'cover_image': null,
          'release_date': null,
          'duration_minutes': 120,
          'is_subscribed': false,
          'can_play': true,
        },
      ],
    );

    final results = await moviesApi.searchLocalMovies(movieNumber: 'ABP-123');

    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/movies/search/local');
    expect(request.uri.queryParameters['movie_number'], 'ABP-123');
    expect(results.single.movieNumber, 'ABP-123');
  });

  test('searchLocalMovies converts backend error to ApiException', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/movies/search/local',
      statusCode: 404,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'movie_not_found',
          'message': '影片不存在',
        },
      },
    );

    expect(
      () => moviesApi.searchLocalMovies(movieNumber: 'ABP-123'),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.error?.code,
          'error.code',
          'movie_not_found',
        ),
      ),
    );
  });

  test('searchOnlineMoviesStream parses completed SSE result', () async {
    adapter.enqueueSse(
      method: 'POST',
      path: '/movies/search/javdb/stream',
      chunks: <String>[
        'event: search_started\n'
            'data: {"movie_number":"ABP-123"}\n\n',
        'event: movie_found\n'
            'data: {"movies":[{"javdb_id":"javdb-ABP-123","movie_number":"ABP-123","title":"title-ABP-123","cover_image":"https://example.com/cover.jpg"}],"total":1}\n\n',
        'event: upsert_started\n'
            'data: {"total":1}\n\n',
        'event: completed\n'
            'data: {"success":true,"movies":[{"javdb_id":"MovieA1","movie_number":"ABP-123","title":"Movie 1","cover_image":null,"release_date":null,"duration_minutes":120,"is_subscribed":false,"can_play":true}],"failed_items":[],"stats":{"total":1,"created_count":1,"already_exists_count":0,"failed_count":0}}\n\n',
      ],
    );

    final updates =
        await moviesApi
            .searchOnlineMoviesStream(movieNumber: 'ABP-123')
            .toList();

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/movies/search/javdb/stream');
    expect(request.body, <String, dynamic>{'movie_number': 'ABP-123'});
    expect(updates.last.message, '在线搜索已完成');
    expect(updates.last.success, isTrue);
    expect(updates.last.results.single.movieNumber, 'ABP-123');
  });

  test(
    'searchOnlineMoviesStream keeps not found as non-error completion',
    () async {
      adapter.enqueueSse(
        method: 'POST',
        path: '/movies/search/javdb/stream',
        chunks: <String>[
          'event: search_started\n'
              'data: {"movie_number":"ABP-404"}\n\n',
          'event: completed\n'
              'data: {"success":false,"reason":"movie_not_found","movies":[]}\n\n',
        ],
      );

      final updates =
          await moviesApi
              .searchOnlineMoviesStream(movieNumber: 'ABP-404')
              .toList();

      expect(updates.last.success, isFalse);
      expect(updates.last.reason, 'movie_not_found');
      expect(updates.last.results, isEmpty);
    },
  );

  test('searchOnlineMoviesStream supports chunked SSE events', () async {
    adapter.enqueueSse(
      method: 'POST',
      path: '/movies/search/javdb/stream',
      chunks: <String>[
        'event: completed\n',
        'data: {"success":true,"movies":[{"javdb_id":"MovieA1",',
        '"movie_number":"ABP-123","title":"Movie 1","cover_image":null,',
        '"release_date":null,"duration_minutes":120,"is_subscribed":false,"can_play":true}],"failed_items":[],"stats":{"total":1,"created_count":1,"already_exists_count":0,"failed_count":0}}\n\n',
      ],
    );

    final updates =
        await moviesApi
            .searchOnlineMoviesStream(movieNumber: 'ABP-123')
            .toList();

    expect(updates.single.results.single.movieNumber, 'ABP-123');
  });

  test(
    'searchOnlineMoviesStream converts invalid SSE payload to ApiException',
    () async {
      adapter.enqueueSse(
        method: 'POST',
        path: '/movies/search/javdb/stream',
        chunks: <String>[
          'event: completed\n'
              'data: not-json\n\n',
        ],
      );

      expect(
        () =>
            moviesApi.searchOnlineMoviesStream(movieNumber: 'ABP-123').toList(),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test('getLatestMovies parses paginated movie response', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/movies/latest',
      statusCode: 200,
      body: <String, dynamic>{
        'items': [
          <String, dynamic>{
            'javdb_id': 'MovieA1',
            'movie_number': 'ABC-001',
            'title': 'Movie 1',
            'cover_image': <String, dynamic>{
              'id': 10,
              'origin': 'origin.jpg',
              'small': 'small.jpg',
              'medium': 'medium.jpg',
              'large': 'large.jpg',
            },
            'release_date': '2024-01-02',
            'duration_minutes': 120,
            'is_subscribed': true,
            'can_play': true,
          },
        ],
        'page': 1,
        'page_size': 8,
        'total': 1,
      },
    );

    final page = await moviesApi.getLatestMovies(page: 1, pageSize: 8);

    expect(page.page, 1);
    expect(page.pageSize, 8);
    expect(page.total, 1);
    expect(page.items.single.movieNumber, 'ABC-001');
    expect(page.items.single.coverImage?.bestAvailableUrl, 'large.jpg');
    expect(page.items.single.releaseDate, DateTime.parse('2024-01-02'));
    expect(page.items.single.canPlay, isTrue);
  });

  test('getLatestMovies converts backend error to ApiException', () async {
    await sessionStore.clearSession();
    adapter.enqueueJson(
      method: 'GET',
      path: '/movies/latest',
      statusCode: 401,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'unauthorized',
          'message': 'Unauthorized',
        },
      },
    );

    expect(
      () => moviesApi.getLatestMovies(page: 1, pageSize: 8),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.error?.code,
          'error.code',
          'unauthorized',
        ),
      ),
    );
  });

  test('getSubscribedActorsLatestMovies parses paginated response', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/movies/subscribed-actors/latest',
      statusCode: 200,
      body: <String, dynamic>{
        'items': [
          <String, dynamic>{
            'javdb_id': 'MovieA2',
            'movie_number': 'ABC-002',
            'title': 'Movie 2',
            'cover_image': null,
            'release_date': '2026-03-10',
            'duration_minutes': 130,
            'is_subscribed': false,
            'can_play': true,
          },
        ],
        'page': 1,
        'page_size': 10,
        'total': 1,
      },
    );

    final page = await moviesApi.getSubscribedActorsLatestMovies(
      page: 1,
      pageSize: 10,
    );

    final request = adapter.requests.single;
    expect(request.path, '/movies/subscribed-actors/latest');
    expect(request.uri.queryParameters['page'], '1');
    expect(request.uri.queryParameters['page_size'], '10');
    expect(page.total, 1);
    expect(page.items.single.movieNumber, 'ABC-002');
    expect(page.items.single.releaseDate, DateTime.parse('2026-03-10'));
  });

  test('getSubscribedActorsLatestMovies converts backend error', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/movies/subscribed-actors/latest',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
      },
    );

    expect(
      () => moviesApi.getSubscribedActorsLatestMovies(page: 1, pageSize: 10),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.error?.code,
          'error.code',
          'server_error',
        ),
      ),
    );
  });

  test('getMovieDetail parses full movie detail response', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001',
      statusCode: 200,
      body: <String, dynamic>{
        'javdb_id': 'MovieA1',
        'movie_number': 'ABC-001',
        'title': 'Movie 1',
        'cover_image': <String, dynamic>{
          'id': 10,
          'origin': 'cover-origin.jpg',
          'small': 'cover-small.jpg',
          'medium': 'cover-medium.jpg',
          'large': 'cover-large.jpg',
        },
        'release_date': '2024-01-02',
        'duration_minutes': 120,
        'score': 4.5,
        'watched_count': 12,
        'want_watch_count': 23,
        'comment_count': 34,
        'score_number': 45,
        'is_collection': true,
        'is_subscribed': false,
        'can_play': true,
        'series_name': 'Series 1',
        'maker_name': 'S1 NO.1 STYLE',
        'director_name': '紋℃',
        'summary': 'summary',
        'actors': [
          <String, dynamic>{
            'id': 1,
            'javdb_id': 'ActorA1',
            'name': '三上悠亚',
            'alias_name': '三上悠亚 / 鬼头桃菜',
            'is_subscribed': false,
            'profile_image': <String, dynamic>{
              'id': 11,
              'origin': 'actor-origin.jpg',
              'small': 'actor-small.jpg',
              'medium': 'actor-medium.jpg',
              'large': 'actor-large.jpg',
            },
          },
        ],
        'tags': [
          <String, dynamic>{'tag_id': 1, 'name': '剧情'},
        ],
        'thin_cover_image': <String, dynamic>{
          'id': 12,
          'origin': 'thin-origin.jpg',
          'small': 'thin-small.jpg',
          'medium': 'thin-medium.jpg',
          'large': 'thin-large.jpg',
        },
        'plot_images': [
          <String, dynamic>{
            'id': 13,
            'origin': 'plot-origin.jpg',
            'small': 'plot-small.jpg',
            'medium': 'plot-medium.jpg',
            'large': 'plot-large.jpg',
          },
        ],
        'playlists': [
          <String, dynamic>{
            'id': 1,
            'name': '最近播放',
            'kind': 'recently_played',
            'is_system': true,
          },
          <String, dynamic>{
            'id': 2,
            'name': '我的收藏',
            'kind': 'custom',
            'is_system': false,
          },
        ],
        'media_items': [
          <String, dynamic>{
            'media_id': 100,
            'library_id': 1,
            'play_url':
                '/files/media/movies/ABC-001/video.mp4?expires=1700000900&signature=abc',
            'path': '/library/main/ABC-001/video.mp4',
            'storage_mode': 'hardlink',
            'resolution': '1920x1080',
            'file_size_bytes': 1073741824,
            'duration_seconds': 7200,
            'special_tags': '普通',
            'valid': true,
            'progress': <String, dynamic>{
              'last_position_seconds': 600,
              'last_watched_at': '2026-03-08T09:30:00',
            },
            'points': [
              <String, dynamic>{'point_id': 1, 'offset_seconds': 120},
            ],
          },
        ],
      },
    );

    final detail = await moviesApi.getMovieDetail(movieNumber: 'ABC-001');

    expect(detail, isA<MovieDetailDto>());
    expect(detail.movieNumber, 'ABC-001');
    expect(detail.seriesName, 'Series 1');
    expect(detail.makerName, 'S1 NO.1 STYLE');
    expect(detail.directorName, '紋℃');
    expect(detail.coverImage?.bestAvailableUrl, 'cover-large.jpg');
    expect(detail.thinCoverImage?.bestAvailableUrl, 'thin-large.jpg');
    expect(detail.plotImages.single.bestAvailableUrl, 'plot-large.jpg');
    expect(detail.actors.single.aliasName, '三上悠亚 / 鬼头桃菜');
    expect(detail.tags.single.name, '剧情');
    expect(
      detail.mediaItems.single.playUrl,
      '/files/media/movies/ABC-001/video.mp4?expires=1700000900&signature=abc',
    );
    expect(detail.mediaItems.single.hasPlayableUrl, isTrue);
    expect(detail.mediaItems.single.progress?.lastPositionSeconds, 600);
    expect(detail.mediaItems.single.points.single.offsetSeconds, 120);
    expect(detail.playlists, hasLength(2));
    expect(detail.playlists.first.name, '最近播放');
    expect(detail.playlists.first.isSystem, isTrue);
    expect(detail.playlists.last.kind, 'custom');
  });

  test('getMovieDetail handles nullable detail sections', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-002',
      statusCode: 200,
      body: <String, dynamic>{
        'javdb_id': 'MovieA2',
        'movie_number': 'ABC-002',
        'title': 'Movie 2',
        'cover_image': null,
        'release_date': null,
        'duration_minutes': 0,
        'score': 0.0,
        'watched_count': 0,
        'want_watch_count': 0,
        'comment_count': 0,
        'score_number': 0,
        'is_collection': false,
        'is_subscribed': false,
        'can_play': false,
        'series_name': null,
        'maker_name': null,
        'director_name': null,
        'summary': '',
        'actors': [],
        'tags': [],
        'thin_cover_image': null,
        'plot_images': [],
        'media_items': [],
      },
    );

    final detail = await moviesApi.getMovieDetail(movieNumber: 'ABC-002');

    expect(detail.coverImage, isNull);
    expect(detail.seriesName, '');
    expect(detail.makerName, '');
    expect(detail.directorName, '');
    expect(detail.thinCoverImage, isNull);
    expect(detail.plotImages, isEmpty);
    expect(detail.mediaItems, isEmpty);
  });

  test('getMovieDetail converts movie not found to ApiException', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-404',
      statusCode: 404,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'movie_not_found',
          'message': '影片不存在',
        },
      },
    );

    expect(
      () => moviesApi.getMovieDetail(movieNumber: 'ABC-404'),
      throwsA(
        isA<ApiException>()
            .having((ApiException error) => error.statusCode, 'statusCode', 404)
            .having(
              (ApiException error) => error.error?.code,
              'error.code',
              'movie_not_found',
            ),
      ),
    );
  });

  test('getMovieReviews sends query and parses review list', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001/reviews',
      statusCode: 200,
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'score': 5,
          'content': '很不错',
          'created_at': '2026-03-10T08:00:00Z',
          'username': 'tester',
          'like_count': 8,
          'watch_count': 15,
        },
      ],
    );

    final reviews = await moviesApi.getMovieReviews(
      movieNumber: 'ABC-001',
      page: 2,
      pageSize: 5,
      sort: MovieReviewSort.hotly,
    );

    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/movies/ABC-001/reviews');
    expect(request.uri.queryParameters['page'], '2');
    expect(request.uri.queryParameters['page_size'], '5');
    expect(request.uri.queryParameters['sort'], 'hotly');
    expect(reviews, hasLength(1));
    expect(reviews.single.score, 5);
    expect(reviews.single.username, 'tester');
    expect(reviews.single.createdAt, DateTime.parse('2026-03-10T08:00:00Z'));
  });

  test('getMovieReviews preserves backend ApiException payload', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-404/reviews',
      statusCode: 404,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'movie_not_found',
          'message': '影片不存在',
        },
      },
    );

    expect(
      () => moviesApi.getMovieReviews(movieNumber: 'ABC-404'),
      throwsA(
        isA<ApiException>()
            .having((ApiException error) => error.statusCode, 'statusCode', 404)
            .having(
              (ApiException error) => error.error?.code,
              'error.code',
              'movie_not_found',
            ),
      ),
    );
  });

  test('getMediaThumbnails parses thumbnail list response', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/100/thumbnails',
      statusCode: 200,
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'thumbnail_id': 5,
          'media_id': 100,
          'offset_seconds': 10,
          'image': <String, dynamic>{
            'id': 88,
            'origin': 'thumb-origin.webp',
            'small': 'thumb-small.webp',
            'medium': 'thumb-medium.webp',
            'large': 'thumb-large.webp',
          },
        },
      ],
    );

    final thumbnails = await moviesApi.getMediaThumbnails(mediaId: 100);

    expect(thumbnails, hasLength(1));
    expect(thumbnails.single, isA<MovieMediaThumbnailDto>());
    expect(thumbnails.single.thumbnailId, 5);
    expect(thumbnails.single.mediaId, 100);
    expect(thumbnails.single.offsetSeconds, 10);
    expect(thumbnails.single.image.bestAvailableUrl, 'thumb-large.webp');
    expect(adapter.requests.single.path, '/media/100/thumbnails');
  });

  test(
    'getMediaThumbnails returns empty list when backend has no thumbnails',
    () async {
      adapter.enqueueJson(
        method: 'GET',
        path: '/media/100/thumbnails',
        statusCode: 200,
        body: const <Map<String, dynamic>>[],
      );

      final thumbnails = await moviesApi.getMediaThumbnails(mediaId: 100);

      expect(thumbnails, isEmpty);
    },
  );

  test('getMediaThumbnails preserves backend ApiException payload', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/media/404/thumbnails',
      statusCode: 404,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'media_not_found',
          'message': '资源不存在',
        },
      },
    );

    expect(
      () => moviesApi.getMediaThumbnails(mediaId: 404),
      throwsA(
        isA<ApiException>()
            .having((ApiException error) => error.statusCode, 'statusCode', 404)
            .having(
              (ApiException error) => error.error?.code,
              'error.code',
              'media_not_found',
            ),
      ),
    );
  });

  test(
    'getMissavThumbnailsStream maps stream progress and completed result',
    () async {
      adapter.enqueueSse(
        method: 'GET',
        path: '/movies/SSNI-888/thumbnails/missav/stream',
        chunks: <String>[
          'event: search_started\n'
              'data: {"movie_number":"SSNI-888","refresh":false}\n\n',
          'event: download_progress\n'
              'data: {"completed":1,"total":3}\n\n',
          'event: completed\n'
              'data: {"success":true,"result":{"movie_number":"SSNI-888","source":"missav","total":2,"items":[{"index":0,"url":"/missav-0.jpg"},{"index":1,"url":"/missav-1.jpg"}]}}\n\n',
        ],
      );

      final updates =
          await moviesApi
              .getMissavThumbnailsStream(movieNumber: 'SSNI-888')
              .toList();

      expect(updates, hasLength(3));
      expect(updates[0].stage, 'search_started');
      expect(updates[0].message, '正在获取 MissAV 缩略图');
      expect(updates[1].stage, 'download_progress');
      expect(updates[1].current, 1);
      expect(updates[1].total, 3);
      expect(updates[2].stage, 'completed');
      expect(updates[2].success, isTrue);
      expect(updates[2].result?.movieNumber, 'SSNI-888');
      expect(updates[2].result?.items, hasLength(2));
      expect(updates[2].result?.items[1].url, '/missav-1.jpg');

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/movies/SSNI-888/thumbnails/missav/stream');
      expect(request.uri.queryParameters['refresh'], 'false');
    },
  );

  test(
    'getMissavThumbnailsStream preserves completed failure reason and detail',
    () async {
      adapter.enqueueSse(
        method: 'GET',
        path: '/movies/SSNI-888/thumbnails/missav/stream',
        chunks: <String>[
          'event: completed\n'
              'data: {"success":false,"reason":"missav_thumbnail_not_found","detail":"thumbnail config missing"}\n\n',
        ],
      );

      final updates =
          await moviesApi
              .getMissavThumbnailsStream(movieNumber: 'SSNI-888', refresh: true)
              .toList();

      expect(updates.single.stage, 'completed');
      expect(updates.single.success, isFalse);
      expect(updates.single.reason, 'missav_thumbnail_not_found');
      expect(updates.single.detail, 'thumbnail config missing');
      expect(adapter.requests.single.uri.queryParameters['refresh'], 'true');
    },
  );

  test(
    'updateMediaProgress sends position_seconds and parses response',
    () async {
      adapter.enqueueJson(
        method: 'PUT',
        path: '/media/100/progress',
        statusCode: 200,
        body: <String, dynamic>{
          'media_id': 100,
          'last_position_seconds': 615,
          'last_watched_at': '2026-03-12T14:00:00',
        },
      );

      final progress = await moviesApi.updateMediaProgress(
        mediaId: 100,
        positionSeconds: 615,
      );

      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/media/100/progress');
      expect(request.body, <String, dynamic>{'position_seconds': 615});
      expect(progress.lastPositionSeconds, 615);
      expect(progress.lastWatchedAt, DateTime.parse('2026-03-12T14:00:00'));
    },
  );

  test('updateMediaProgress preserves backend ApiException payload', () async {
    await sessionStore.clearSession();
    adapter.enqueueJson(
      method: 'PUT',
      path: '/media/100/progress',
      statusCode: 401,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'unauthorized',
          'message': 'Unauthorized',
        },
      },
    );

    expect(
      () => moviesApi.updateMediaProgress(mediaId: 100, positionSeconds: 615),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.error?.code,
          'error.code',
          'unauthorized',
        ),
      ),
    );
  });

  test(
    'subscribeMovie sends PUT request to movie subscription endpoint',
    () async {
      adapter.enqueueJson(
        method: 'PUT',
        path: '/movies/ABC-001/subscription',
        statusCode: 204,
      );

      await moviesApi.subscribeMovie(movieNumber: 'ABC-001');

      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/movies/ABC-001/subscription');
      expect(request.uri.queryParameters, isEmpty);
    },
  );

  test(
    'unsubscribeMovie sends DELETE request with delete_media=false by default',
    () async {
      adapter.enqueueJson(
        method: 'DELETE',
        path: '/movies/ABC-001/subscription',
        statusCode: 204,
      );

      await moviesApi.unsubscribeMovie(movieNumber: 'ABC-001');

      final request = adapter.requests.single;
      expect(request.method, 'DELETE');
      expect(request.path, '/movies/ABC-001/subscription');
      expect(request.uri.queryParameters['delete_media'], 'false');
    },
  );

  test('unsubscribeMovie preserves backend ApiException payload', () async {
    adapter.enqueueJson(
      method: 'DELETE',
      path: '/movies/ABC-001/subscription',
      statusCode: 409,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'movie_subscription_has_media',
          'message': '影片存在媒体文件，若需取消订阅请传 delete_media=true',
        },
      },
    );

    expect(
      () => moviesApi.unsubscribeMovie(movieNumber: 'ABC-001'),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.error?.code,
          'error.code',
          'movie_subscription_has_media',
        ),
      ),
    );
  });
}
