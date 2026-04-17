import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MovieDetailController', () {
    test('refresh updates movie detail after initial load', () async {
      var cycle = 0;
      final controller = MovieDetailController(
        movieNumber: 'ABC-001',
        fetchMovieDetail: ({required movieNumber}) async {
          cycle += 1;
          return _movieDetail(
            title: cycle == 1 ? 'Old title' : 'New title',
            coverOrigin: cycle == 1 ? '/covers/old.jpg' : '/covers/new.jpg',
          );
        },
      );

      await controller.load();
      await controller.refresh();

      expect(controller.movie?.title, 'New title');
      expect(controller.selectedPreviewUrl, '/covers/new.jpg');
      expect(controller.errorMessage, isNull);
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
        );

        await controller.load();

        await expectLater(controller.refresh(), throwsException);

        expect(controller.movie?.title, 'Old title');
        expect(controller.selectedPreviewUrl, '/covers/old.jpg');
        expect(controller.errorMessage, isNull);
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
