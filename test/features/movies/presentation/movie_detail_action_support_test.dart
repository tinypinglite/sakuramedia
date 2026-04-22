import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_action_copy.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_action_menu.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_action_support.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_controller.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_change_notifier.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'buildMovieDetailActionDescriptors keeps action order and prerequisites',
    () {
      final movie = _movieDetail(javdbId: '', desc: '');

      final actions = buildMovieDetailActionDescriptors(
        movie: movie,
        isSubscribed: false,
      );

      expect(actions.map((action) => action.type), <MovieDetailActionType>[
        MovieDetailActionType.toggleSubscription,
        MovieDetailActionType.refreshMetadata,
        MovieDetailActionType.recomputeHeat,
        MovieDetailActionType.syncInteraction,
        MovieDetailActionType.translateDescription,
      ]);
      expect(actions[3].enabled, isFalse);
      expect(actions[4].enabled, isFalse);
    },
  );

  test('movieDetailRemoteActionSpecFor maps refresh metadata action', () async {
    final spec = await _runRemoteActionSpec(
      action: MovieDetailActionType.refreshMetadata,
      expectedPath: '/movies/ABC-001/metadata-refresh',
    );

    expect(spec.successMessage, '影片元数据已刷新');
    expect(spec.failureMessage, '刷新影片元数据失败');
    expect(spec.resetPreview, isTrue);
  });

  test('movieDetailRemoteActionSpecFor maps recompute heat action', () async {
    final spec = await _runRemoteActionSpec(
      action: MovieDetailActionType.recomputeHeat,
      expectedPath: '/movies/ABC-001/heat-recompute',
    );

    expect(spec.successMessage, '影片热度已更新');
    expect(spec.failureMessage, '计算影片热度失败');
    expect(spec.resetPreview, isFalse);
  });

  test('movieDetailRemoteActionSpecFor maps sync interaction action', () async {
    final spec = await _runRemoteActionSpec(
      action: MovieDetailActionType.syncInteraction,
      expectedPath: '/movies/ABC-001/interaction-sync',
    );

    expect(spec.successMessage, '影片互动数已同步');
    expect(spec.failureMessage, '刷新影片互动数失败');
    expect(spec.resetPreview, isFalse);
  });

  test(
    'movieDetailRemoteActionSpecFor maps translate description action',
    () async {
      final spec = await _runRemoteActionSpec(
        action: MovieDetailActionType.translateDescription,
        expectedPath: '/movies/ABC-001/desc-translation',
      );

      expect(spec.successMessage, '影片介绍已翻译');
      expect(spec.failureMessage, '翻译影片介绍失败');
      expect(spec.resetPreview, isFalse);
    },
  );

  test(
    'applyReturnedMovieDetail keeps selected media when still present',
    () async {
      final controller = _buildController();
      addTearDown(controller.dispose);
      await controller.load();

      final result = applyReturnedMovieDetail(
        controller: controller,
        movie: _movieDetail(mediaIds: const <int>[10, 20]),
        selectedMediaId: 20,
        resetPreview: false,
      );

      expect(result.selectedMediaId, 20);
      expect(result.isSubscribedOverride, isNull);
      expect(result.isCollectionOverride, isNull);
    },
  );

  test(
    'applyReturnedMovieDetail falls back to first media when selection disappears',
    () async {
      final controller = _buildController();
      addTearDown(controller.dispose);
      await controller.load();

      final result = applyReturnedMovieDetail(
        controller: controller,
        movie: _movieDetail(mediaIds: const <int>[30, 40]),
        selectedMediaId: 20,
        resetPreview: false,
      );

      expect(result.selectedMediaId, 30);
    },
  );

  test(
    'applyReturnedMovieDetail clears selection when no media remain',
    () async {
      final controller = _buildController();
      addTearDown(controller.dispose);
      await controller.load();

      final result = applyReturnedMovieDetail(
        controller: controller,
        movie: _movieDetail(mediaIds: const <int>[]),
        selectedMediaId: 20,
        resetPreview: false,
      );

      expect(result.selectedMediaId, isNull);
    },
  );

  testWidgets('resolveMovieSubscriptionNotifier reuses provider value', (
    WidgetTester tester,
  ) async {
    final notifier = MovieSubscriptionChangeNotifier();
    late MovieSubscriptionNotifierBinding binding;

    await tester.pumpWidget(
      ChangeNotifierProvider<MovieSubscriptionChangeNotifier>.value(
        value: notifier,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              binding = resolveMovieSubscriptionNotifier(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(binding.notifier, same(notifier));
    expect(binding.ownsNotifier, isFalse);
  });

  testWidgets(
    'resolveMovieSubscriptionNotifier creates fallback when provider is missing',
    (WidgetTester tester) async {
      late MovieSubscriptionNotifierBinding binding;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              binding = resolveMovieSubscriptionNotifier(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(binding.notifier, isA<MovieSubscriptionChangeNotifier>());
      expect(binding.ownsNotifier, isTrue);
    },
  );

  test('refresh confirmation copy is shared', () {
    expect(MovieDetailRefreshConfirmationCopy.title, '刷新元数据');
    expect(
      MovieDetailRefreshConfirmationCopy.description,
      '刷新后会重新下载封面图和剧情图，并重新绑定当前影片的女优和标签关联。',
    );
    expect(
      MovieDetailRefreshConfirmationCopy.hint,
      '这是一次覆盖式刷新，影片本地元数据会以远端最新结果为准。',
    );
    expect(MovieDetailRefreshConfirmationCopy.cancelLabel, '取消');
    expect(MovieDetailRefreshConfirmationCopy.confirmLabel, '确认刷新');
  });
}

Future<MovieDetailRemoteActionSpec> _runRemoteActionSpec({
  required MovieDetailActionType action,
  required String expectedPath,
}) async {
  final sessionStore = SessionStore.inMemory();
  await sessionStore.saveBaseUrl('https://api.example.com');
  await sessionStore.saveTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.parse('2026-03-08T10:00:00Z'),
  );
  final apiClient = ApiClient(sessionStore: sessionStore);
  final adapter = FakeHttpClientAdapter();
  apiClient.rawDio.httpClientAdapter = adapter;
  apiClient.rawRefreshDio.httpClientAdapter = adapter;
  final moviesApi = MoviesApi(apiClient: apiClient);
  final spec =
      movieDetailRemoteActionSpecFor(action: action, movieNumber: 'ABC-001')!;
  adapter.enqueueJson(
    method: 'POST',
    path: expectedPath,
    body: <String, dynamic>{
      'javdb_id': 'movie-1',
      'movie_number': 'ABC-001',
      'title': 'Movie',
      'series_name': '',
      'maker_name': '',
      'director_name': '',
      'cover_image': null,
      'release_date': '2024-01-01',
      'duration_minutes': 120,
      'score': 4.5,
      'heat': 1,
      'watched_count': 1,
      'want_watch_count': 2,
      'comment_count': 3,
      'score_number': 4,
      'is_collection': false,
      'is_subscribed': false,
      'can_play': true,
      'summary': '',
      'desc_zh': '',
      'desc': 'desc',
      'thin_cover_image': null,
      'plot_images': const <Map<String, dynamic>>[],
      'actors': const <Map<String, dynamic>>[],
      'tags': const <Map<String, dynamic>>[],
      'media_items': const <Map<String, dynamic>>[],
      'playlists': const <Map<String, dynamic>>[],
    },
  );

  await spec.request(moviesApi);
  expect(adapter.requests.single.path, expectedPath);
  apiClient.dispose();
  return spec;
}

MovieDetailController _buildController() {
  return MovieDetailController(
    movieNumber: 'ABC-001',
    fetchMovieDetail: ({required movieNumber}) async => _movieDetail(),
    fetchSimilarMovies:
        ({required movieNumber, int limit = 15}) async => <MovieListItemDto>[
          _similarMovie(),
        ],
  );
}

MovieDetailDto _movieDetail({
  String javdbId = 'movie-1',
  String desc = 'desc',
  List<int> mediaIds = const <int>[10, 20],
}) {
  return MovieDetailDto(
    javdbId: javdbId,
    movieNumber: 'ABC-001',
    title: 'Movie',
    titleZh: '',
    seriesName: '',
    makerName: '',
    directorName: '',
    coverImage: const MovieImageDto(
      id: 1,
      origin: '/covers/1.jpg',
      small: '',
      medium: '',
      large: '',
    ),
    releaseDate: DateTime.parse('2024-01-01'),
    durationMinutes: 120,
    score: 4.5,
    heat: 12,
    watchedCount: 1,
    wantWatchCount: 2,
    commentCount: 3,
    scoreNumber: 4,
    isCollection: false,
    isSubscribed: false,
    canPlay: true,
    summary: '',
    descZh: '',
    desc: desc,
    thinCoverImage: null,
    plotImages: const <MovieImageDto>[],
    actors: const <MovieActorDto>[],
    tags: const <MovieTagDto>[],
    mediaItems: mediaIds
        .map(
          (mediaId) => MovieMediaItemDto(
            mediaId: mediaId,
            libraryId: 1,
            playUrl: '/play/$mediaId',
            path: '/media/$mediaId.mp4',
            storageMode: 'local',
            resolution: '1080p',
            fileSizeBytes: 10,
            durationSeconds: 120,
            specialTags: '',
            valid: true,
            progress: null,
            points: const <MovieMediaPointDto>[],
            videoInfo: null,
          ),
        )
        .toList(growable: false),
    playlists: const <MoviePlaylistSummaryDto>[],
  );
}

MovieListItemDto _similarMovie() {
  return const MovieListItemDto(
    javdbId: 'similar-1',
    movieNumber: 'SIM-001',
    title: 'Similar',
    titleZh: '',
    coverImage: null,
    releaseDate: null,
    durationMinutes: 0,
    heat: 0,
    isSubscribed: false,
    canPlay: false,
  );
}
