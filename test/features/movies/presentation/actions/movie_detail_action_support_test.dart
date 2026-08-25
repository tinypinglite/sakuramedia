import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_detail_action_copy.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_detail_action_menu.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_detail_action_support.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';

import '../../../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'buildMovieDetailActionDescriptors keeps action order and prerequisites',
    () {
      final movie = _movieDetail(javdbId: '');

      final actions = buildMovieDetailActionDescriptors(
        movie: movie,
        isSubscribed: false,
        isBlacklisted: false,
      );

      expect(actions.map((action) => action.type), <MovieDetailActionType>[
        MovieDetailActionType.openInspector,
        MovieDetailActionType.toggleSubscription,
        MovieDetailActionType.toggleBlacklist,
        MovieDetailActionType.refreshMetadata,
        MovieDetailActionType.recomputeHeat,
      ]);

      final blacklistedActions = buildMovieDetailActionDescriptors(
        movie: movie,
        isSubscribed: false,
        isBlacklisted: true,
      );
      expect(
        blacklistedActions.map((action) => action.type),
        isNot(contains(MovieDetailActionType.toggleSubscription)),
      );
      expect(blacklistedActions[1].label, '取消屏蔽');
    },
  );

  test(
    'movieDetailRemoteActionSpecFor has no remote spec for openInspector',
    () {
      expect(
        movieDetailRemoteActionSpecFor(
          action: MovieDetailActionType.openInspector,
          movieNumber: 'ABC-001',
        ),
        isNull,
      );
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

    expect(spec.successMessage, '影片热度重算任务已提交，请在活动中心查看进度');
    expect(spec.failureMessage, '计算影片热度失败');
    expect(spec.resetPreview, isFalse);
  });

  testWidgets(
    'applyReturnedMovieDetail keeps selected media when still present',
    (WidgetTester tester) async {
      final result = await _runApplyReturnedMovieDetail(
        tester,
        movie: _movieDetail(mediaIds: const <int>[10, 20]),
        selectedMediaId: 20,
      );

      expect(result.selectedMediaId, 20);
      expect(result.isSubscribedOverride, isNull);
      expect(result.isCollectionOverride, isNull);
    },
  );

  testWidgets(
    'applyReturnedMovieDetail falls back to first media when selection disappears',
    (WidgetTester tester) async {
      final result = await _runApplyReturnedMovieDetail(
        tester,
        movie: _movieDetail(mediaIds: const <int>[30, 40]),
        selectedMediaId: 20,
      );

      expect(result.selectedMediaId, 30);
    },
  );

  testWidgets(
    'applyReturnedMovieDetail clears selection when no media remain',
    (WidgetTester tester) async {
      final result = await _runApplyReturnedMovieDetail(
        tester,
        movie: _movieDetail(mediaIds: const <int>[]),
        selectedMediaId: 20,
      );

      expect(result.selectedMediaId, isNull);
    },
  );

  testWidgets(
    'resolveMovieSubscriptionNotifier returns the same events notifier '
    'that publishers use',
    (WidgetTester tester) async {
      late MovieSubscriptionEvents resolved;
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                container = ProviderScope.containerOf(context, listen: false);
                resolved = resolveMovieSubscriptionNotifier(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(
        resolved,
        same(container.read(movieSubscriptionEventsProvider.notifier)),
      );
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
      '这是一次覆盖式刷新，SakuraMedia 中的影片元数据会以远端最新结果为准。',
    );
    expect(MovieDetailRefreshConfirmationCopy.cancelLabel, '取消');
    expect(MovieDetailRefreshConfirmationCopy.confirmLabel, '确认刷新');
  });
}

Future<MovieDetailRemoteActionSpec> _runRemoteActionSpec({
  required MovieDetailActionType action,
  required String expectedPath,
  Map<String, dynamic>? expectedBody,
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
  final spec = movieDetailRemoteActionSpecFor(
    action: action,
    movieNumber: 'ABC-001',
  )!;
  final response = action == MovieDetailActionType.recomputeHeat
      ? <String, dynamic>{
          'task_run_id': 42,
          'task_key': 'movie_heat_update',
          'state': 'pending',
        }
      : <String, dynamic>{
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
          'thin_cover_image': null,
          'plot_images': const <Map<String, dynamic>>[],
          'actors': const <Map<String, dynamic>>[],
          'tags': const <Map<String, dynamic>>[],
          'media_items': const <Map<String, dynamic>>[],
          'playlists': const <Map<String, dynamic>>[],
        };
  adapter.enqueueJson(
    method: 'POST',
    path: expectedPath,
    statusCode: action == MovieDetailActionType.recomputeHeat ? 202 : 200,
    body: response,
  );

  await spec.request(moviesApi);
  expect(adapter.requests.single.path, expectedPath);
  if (expectedBody != null) {
    expect(adapter.requests.single.body, expectedBody);
  }
  apiClient.dispose();
  return spec;
}

/// applyReturnedMovieDetail 需要 [WidgetRef]，用最小 widget test 抓一个 ref。
/// 在 post-frame 里跑，避免 Consumer build 中修改 provider 触发的
/// 「build 中不得修改 provider」断言。
Future<MovieDetailApplyResult> _runApplyReturnedMovieDetail(
  WidgetTester tester, {
  required MovieDetailDto movie,
  required int? selectedMediaId,
  bool resetPreview = false,
  String movieNumber = 'ABC-001',
}) async {
  final completer = Completer<MovieDetailApplyResult>();
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (completer.isCompleted) return;
              completer.complete(
                applyReturnedMovieDetail(
                  ref: ref,
                  movieNumber: movieNumber,
                  movie: movie,
                  selectedMediaId: selectedMediaId,
                  resetPreview: resetPreview,
                ),
              );
            });
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  await tester.pump();
  return completer.future;
}

MovieDetailDto _movieDetail({
  String javdbId = 'movie-1',
  List<int> mediaIds = const <int>[10, 20],
}) {
  return MovieDetailDto(
    javdbId: javdbId,
    movieNumber: 'ABC-001',
    title: 'Movie',
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
    thinCoverImage: null,
    plotImages: const <MovieImageDto>[],
    actors: const <MovieActorDto>[],
    tags: const <MovieTagDto>[],
    mediaItems: mediaIds
        .map(
          (mediaId) => MovieMediaItemDto(
            mediaId: mediaId,
            libraryId: 1,
            providerKey: 'filesystem',
            playUrl: '/play/$mediaId',
            fileName: 'movie.mp4',
            resolution: '1080p',
            fileSizeBytes: 10,
            durationSeconds: 120,
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
