import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_detail_action_result.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_interaction_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_provider.dart';

import '../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;
  late ProviderContainer container;
  late ProviderSubscription<MovieDetailInteractionState> subscription;
  late MovieDetailInteraction notifier;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
    container = ProviderContainer(
      overrides: bundle.riverpodOverrides(),
      retry: (_, _) => null,
    );
    subscription = container.listen(
      movieDetailInteractionProvider('ABC-001'),
      (_, _) {},
    );
    notifier = container.read(
      movieDetailInteractionProvider('ABC-001').notifier,
    );
  });

  tearDown(() {
    subscription.close();
    container.dispose();
    bundle.dispose();
    sessionStore.dispose();
  });

  MovieDetailInteractionState state() =>
      container.read(movieDetailInteractionProvider('ABC-001'));

  test('derives the first media and detail flags before any interaction', () {
    final movie = _movie();
    final derived = state().derive(movie);

    expect(derived.mediaItems.map((item) => item.mediaId), <int>[10, 20]);
    expect(derived.selectedMedia?.mediaId, 10);
    expect(derived.isSubscribed, isTrue);
    expect(derived.isBlacklisted, isFalse);
    expect(derived.isCollection, isFalse);
    expect(derived.isActionControlsLocked, isFalse);
  });

  test('selection and point overrides are local to the page controller', () {
    final movie = _movie();
    notifier.selectMedia(movie.mediaItems[1]);
    notifier.applyPointListOverride(20, <MovieMediaPointDto>[
      _point(91, offsetSeconds: 12),
    ]);

    final derived = state().derive(movie);

    expect(derived.selectedMedia?.mediaId, 20);
    expect(derived.mediaItems[1].points.single.pointId, 91);
    expect(movie.mediaItems[1].points, isEmpty);
  });

  test('resetAfterRefresh falls back when the selected media was deleted', () {
    final detail = container.read(movieDetailProvider('ABC-001').notifier);
    final movie = _movie();
    detail.applyMovie(movie);
    notifier.selectMedia(movie.mediaItems[1]);

    detail.applyMovie(_movie(mediaIds: const <int>[10]));
    notifier.resetAfterRefresh(deletedMediaId: 20);

    expect(state().selectedMediaId, 10);
    expect(
      state().derive(_movie(mediaIds: const <int>[10])).selectedMedia?.mediaId,
      10,
    );
  });

  test(
    'an in-flight movie action locks favorite and blacklist writes',
    () async {
      final requestGate = Completer<void>();
      bundle.adapter.enqueueResponder(
        method: 'PUT',
        path: '/movies/ABC-001/subscription',
        responder: (_, _) async {
          await requestGate.future;
          return ResponseBody.fromBytes(const <int>[], 204);
        },
      );

      final subscribe = notifier.toggleSubscription(isSubscribed: false);
      await Future<void>.delayed(Duration.zero);
      expect(state().isActionLocked, isTrue);

      final favorite = await notifier.toggleFavorite(
        movie: _movie(),
        isFavorite: false,
      );
      final blacklist = await notifier.setBlacklisted(isBlacklisted: true);

      expect(favorite.status, MovieDetailActionResultStatus.ignored);
      expect(blacklist.status, MovieDetailActionResultStatus.ignored);

      requestGate.complete();
      await subscribe;
      expect(state().isActionLocked, isFalse);
      expect(state().derive(_movie()).isSubscribed, isTrue);
    },
  );

  test('blacklist and collection changes update local overrides', () async {
    _enqueue(bundle, method: 'PUT', path: '/movies/blacklist', statusCode: 204);
    final blacklist = await notifier.setBlacklisted(isBlacklisted: true);

    expect(blacklist.status, MovieDetailActionResultStatus.success);
    expect(state().derive(_movie()).isBlacklisted, isTrue);

    _enqueue(
      bundle,
      method: 'PATCH',
      path: '/movies/collection-type',
      body: const <String, dynamic>{'requested_count': 1, 'updated_count': 1},
    );
    final collection = await notifier.toggleCollection(isCollection: false);

    expect(collection.status, MovieDetailActionResultStatus.success);
    expect(state().derive(_movie()).isCollection, isTrue);
  });

  test('favorite toggles the system playlist and reloads membership', () async {
    _enqueue(
      bundle,
      method: 'PUT',
      path: '/playlists/7/movies/ABC-001',
      statusCode: 204,
    );
    _enqueue(
      bundle,
      method: 'GET',
      path: '/movies/ABC-001',
      body: _movieJson(),
    );

    final result = await notifier.toggleFavorite(
      movie: _movie(),
      isFavorite: false,
    );

    expect(result.status, MovieDetailActionResultStatus.success);
    expect(bundle.adapter.hitCount('PUT', '/playlists/7/movies/ABC-001'), 1);
    expect(bundle.adapter.hitCount('GET', '/movies/ABC-001'), 1);
  });

  test(
    'refresh metadata applies the returned detail and keeps media selection',
    () async {
      final detail = container.read(movieDetailProvider('ABC-001').notifier);
      final movie = _movie();
      detail.applyMovie(movie);
      notifier.selectMedia(movie.mediaItems[1]);
      _enqueue(
        bundle,
        method: 'POST',
        path: '/movies/ABC-001/metadata-refresh',
        body: _movieJson(title: 'Refreshed movie'),
      );

      final result = await notifier.refreshMetadata();

      expect(result.status, MovieDetailActionResultStatus.success);
      expect(
        container.read(movieDetailProvider('ABC-001')).movie?.title,
        'Refreshed movie',
      );
      expect(state().selectedMediaId, 20);
      expect(state().isActionLocked, isFalse);
      expect(
        bundle.adapter.hitCount('POST', '/movies/ABC-001/metadata-refresh'),
        1,
      );
    },
  );

  test('refresh metadata locks actions until the request finishes', () async {
    final requestGate = Completer<void>();
    bundle.adapter.enqueueResponder(
      method: 'POST',
      path: '/movies/ABC-001/metadata-refresh',
      responder: (_, _) async {
        await requestGate.future;
        return ResponseBody.fromString(
          jsonEncode(_movieJson(title: 'Refreshed movie')),
          200,
          headers: const <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      },
    );

    final refresh = notifier.refreshMetadata();
    await Future<void>.delayed(Duration.zero);
    expect(state().isActionLocked, isTrue);
    final blacklist = await notifier.setBlacklisted(isBlacklisted: true);
    expect(blacklist.status, MovieDetailActionResultStatus.ignored);

    requestGate.complete();
    final result = await refresh;

    expect(result.status, MovieDetailActionResultStatus.success);
    expect(state().isActionLocked, isFalse);
  });

  test('refresh metadata failure keeps the existing detail', () async {
    final detail = container.read(movieDetailProvider('ABC-001').notifier);
    detail.applyMovie(_movie());
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/movies/ABC-001/metadata-refresh',
      statusCode: 502,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'movie_metadata_refresh_failed',
          'message': '刷新失败',
        },
      },
    );

    final result = await notifier.refreshMetadata();

    expect(result.status, MovieDetailActionResultStatus.error);
    expect(
      container.read(movieDetailProvider('ABC-001')).movie?.title,
      'Movie 1',
    );
    expect(state().isActionLocked, isFalse);
  });
}

MovieDetailDto _movie({List<int> mediaIds = const <int>[10, 20]}) {
  return MovieDetailDto.fromJson(_movieJson(mediaIds: mediaIds));
}

MovieMediaPointDto _point(int id, {int offsetSeconds = 0}) {
  return MovieMediaPointDto(
    pointId: id,
    thumbnailId: id,
    offsetSeconds: offsetSeconds,
    image: null,
  );
}

Map<String, dynamic> _movieJson({
  List<int> mediaIds = const <int>[10, 20],
  String title = 'Movie 1',
}) {
  return <String, dynamic>{
    'id': 5,
    'movie_number': 'ABC-001',
    'title': title,
    'release_date': '2024-01-02',
    'duration_minutes': 120,
    'is_collection': false,
    'is_subscribed': true,
    'is_blacklisted': false,
    'can_play': true,
    'summary': '',
    'actors': const <Map<String, dynamic>>[],
    'tags': const <Map<String, dynamic>>[],
    'plot_images': const <Map<String, dynamic>>[],
    'media_items': <Map<String, dynamic>>[
      for (final id in mediaIds)
        <String, dynamic>{
          'media_id': id,
          'file_name': 'movie-$id.mp4',
          'file_size_bytes': 1024,
          'duration_seconds': 60,
          'play_url': 'https://cdn.example.com/movie-$id.mp4',
          'valid': true,
          'points': const <Map<String, dynamic>>[],
        },
    ],
    'playlists': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 7,
        'name': 'Favorites',
        'kind': 'favorites',
        'is_system': true,
      },
    ],
    'favorite_playlist_id': 7,
  };
}

void _enqueue(
  TestApiBundle bundle, {
  required String method,
  required String path,
  int statusCode = 200,
  Object? body,
}) {
  bundle.adapter.enqueueResponder(
    method: method,
    path: path,
    responder: (_, _) async {
      if (statusCode == 204) {
        return ResponseBody.fromBytes(const <int>[], 204);
      }
      return ResponseBody.fromString(
        jsonEncode(body ?? const <String, dynamic>{}),
        statusCode,
        headers: const <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
    },
  );
}
