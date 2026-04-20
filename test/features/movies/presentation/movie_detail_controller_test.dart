import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MovieDetailController', () {
    test('refresh updates movie detail after initial load', () async {
      var cycle = 0;
      var similarCycle = 0;
      final controller = MovieDetailController(
        movieNumber: 'ABC-001',
        fetchMovieDetail: ({required movieNumber}) async {
          cycle += 1;
          return _movieDetail(
            title: cycle == 1 ? 'Old title' : 'New title',
            coverOrigin: cycle == 1 ? '/covers/old.jpg' : '/covers/new.jpg',
          );
        },
        fetchSimilarMovies: ({required movieNumber, int limit = 15}) async {
          similarCycle += 1;
          return <MovieListItemDto>[
            _similarMovie(
              movieNumber: similarCycle == 1 ? 'SIM-001' : 'SIM-002',
            ),
          ];
        },
      );

      await controller.load();
      await controller.refresh();

      expect(controller.movie?.title, 'New title');
      expect(controller.selectedPreviewUrl, '/covers/new.jpg');
      expect(controller.errorMessage, isNull);
      expect(controller.similarMovies.single.movieNumber, 'SIM-002');
      expect(controller.isSimilarMoviesLoading, isFalse);
      expect(controller.similarMoviesErrorMessage, isNull);
    });

    test(
      'refresh rethrows and keeps existing movie detail on failure',
      () async {
        var cycle = 0;
        final controller = MovieDetailController(
          movieNumber: 'ABC-001',
          fetchMovieDetail: ({required movieNumber}) async {
            cycle += 1;
            if (cycle == 1) {
              return _movieDetail(
                title: 'Old title',
                coverOrigin: '/covers/old.jpg',
              );
            }
            throw Exception('refresh failed');
          },
          fetchSimilarMovies: ({required movieNumber, int limit = 15}) async {
            return <MovieListItemDto>[_similarMovie(movieNumber: 'SIM-001')];
          },
        );

        await controller.load();

        await expectLater(controller.refresh(), throwsException);

        expect(controller.movie?.title, 'Old title');
        expect(controller.selectedPreviewUrl, '/covers/old.jpg');
        expect(controller.errorMessage, isNull);
        expect(controller.similarMovies.single.movieNumber, 'SIM-001');
      },
    );

    test(
      'load stores similar movies when detail and similar requests succeed',
      () async {
        final controller = MovieDetailController(
          movieNumber: 'ABC-001',
          fetchMovieDetail: ({required movieNumber}) async {
            return _movieDetail(title: 'Movie 1', coverOrigin: '/covers/1.jpg');
          },
          fetchSimilarMovies: ({required movieNumber, int limit = 15}) async {
            expect(limit, 15);
            return <MovieListItemDto>[
              _similarMovie(movieNumber: 'SIM-001'),
              _similarMovie(movieNumber: 'SIM-002'),
            ];
          },
        );

        await controller.load();

        expect(controller.movie?.movieNumber, 'ABC-001');
        expect(controller.similarMovies, hasLength(2));
        expect(controller.similarMovies.map((movie) => movie.movieNumber), [
          'SIM-001',
          'SIM-002',
        ]);
        expect(controller.isLoading, isFalse);
        expect(controller.isSimilarMoviesLoading, isFalse);
        expect(controller.similarMoviesErrorMessage, isNull);
      },
    );

    test('load keeps page state successful when similar movies fail', () async {
      final controller = MovieDetailController(
        movieNumber: 'ABC-001',
        fetchMovieDetail: ({required movieNumber}) async {
          return _movieDetail(title: 'Movie 1', coverOrigin: '/covers/1.jpg');
        },
        fetchSimilarMovies: ({required movieNumber, int limit = 15}) async {
          throw Exception('similar failed');
        },
      );

      await controller.load();

      expect(controller.movie?.movieNumber, 'ABC-001');
      expect(controller.errorMessage, isNull);
      expect(controller.similarMovies, isEmpty);
      expect(controller.isLoading, isFalse);
      expect(controller.isSimilarMoviesLoading, isFalse);
      expect(controller.similarMoviesErrorMessage, '相似影片暂时无法加载，请稍后重试');
    });

    test(
      'retryLoadSimilarMovies refreshes similar movie list independently',
      () async {
        var attempt = 0;
        final controller = MovieDetailController(
          movieNumber: 'ABC-001',
          fetchMovieDetail: ({required movieNumber}) async {
            return _movieDetail(title: 'Movie 1', coverOrigin: '/covers/1.jpg');
          },
          fetchSimilarMovies: ({required movieNumber, int limit = 15}) async {
            attempt += 1;
            if (attempt == 1) {
              throw Exception('similar failed');
            }
            return <MovieListItemDto>[_similarMovie(movieNumber: 'SIM-009')];
          },
        );

        await controller.load();
        await controller.retryLoadSimilarMovies();

        expect(controller.movie?.movieNumber, 'ABC-001');
        expect(controller.similarMovies.single.movieNumber, 'SIM-009');
        expect(controller.similarMoviesErrorMessage, isNull);
        expect(controller.isSimilarMoviesLoading, isFalse);
        expect(attempt, 2);
      },
    );
  });
}

MovieDetailDto _movieDetail({
  required String title,
  required String coverOrigin,
}) {
  return MovieDetailDto(
    javdbId: 'movie-1',
    movieNumber: 'ABC-001',
    title: title,
    seriesName: '',
    makerName: '',
    directorName: '',
    coverImage: MovieImageDto(
      id: 1,
      origin: coverOrigin,
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
    desc: '',
    thinCoverImage: null,
    plotImages: const <MovieImageDto>[],
    actors: const <MovieActorDto>[],
    tags: const <MovieTagDto>[],
    mediaItems: const <MovieMediaItemDto>[],
    playlists: const <MoviePlaylistSummaryDto>[],
  );
}

MovieListItemDto _similarMovie({required String movieNumber}) {
  return MovieListItemDto(
    javdbId: 'similar-$movieNumber',
    movieNumber: movieNumber,
    title: 'Similar $movieNumber',
    coverImage: null,
    releaseDate: null,
    durationMinutes: 0,
    heat: 0,
    isSubscribed: false,
    canPlay: false,
  );
}
