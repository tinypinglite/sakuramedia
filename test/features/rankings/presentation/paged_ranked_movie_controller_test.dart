import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/rankings/data/ranked_movie_list_item_dto.dart';
import 'package:sakuramedia/features/rankings/presentation/paged_ranked_movie_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PagedRankedMovieController', () {
    test('refresh replaces first page items', () async {
      var cycle = 0;
      final controller = PagedRankedMovieController(
        subscribeMovie: ({required movieNumber}) async {},
        unsubscribeMovie:
            ({required movieNumber, deleteMedia = false}) async {},
        fetchPage: (page, pageSize) async {
          cycle += 1;
          if (cycle == 1) {
            return PaginatedResponseDto<RankedMovieListItemDto>(
              items: <RankedMovieListItemDto>[_rankedMovie(1)],
              page: 1,
              pageSize: 24,
              total: 2,
            );
          }
          return PaginatedResponseDto<RankedMovieListItemDto>(
            items: <RankedMovieListItemDto>[_rankedMovie(99)],
            page: 1,
            pageSize: 24,
            total: 1,
          );
        },
      );

      await controller.initialize();
      await controller.refresh();

      expect(controller.items.single.movieNumber, 'ABC-099');
      expect(controller.currentPage, 1);
      expect(controller.total, 1);
      expect(controller.hasMore, isFalse);

      controller.dispose();
    });

    test('refresh rethrows and keeps existing items on failure', () async {
      var cycle = 0;
      final controller = PagedRankedMovieController(
        subscribeMovie: ({required movieNumber}) async {},
        unsubscribeMovie:
            ({required movieNumber, deleteMedia = false}) async {},
        fetchPage: (page, pageSize) async {
          cycle += 1;
          if (cycle == 1) {
            return PaginatedResponseDto<RankedMovieListItemDto>(
              items: <RankedMovieListItemDto>[_rankedMovie(1)],
              page: 1,
              pageSize: 24,
              total: 2,
            );
          }
          throw Exception('refresh failed');
        },
      );

      await controller.initialize();

      await expectLater(controller.refresh(), throwsException);

      expect(controller.items.single.movieNumber, 'ABC-001');
      expect(controller.currentPage, 1);
      expect(controller.total, 2);

      controller.dispose();
    });

    test(
      'applySubscriptionChange updates matched ranked movie state',
      () async {
        final controller = PagedRankedMovieController(
          subscribeMovie: ({required movieNumber}) async {},
          unsubscribeMovie:
              ({required movieNumber, deleteMedia = false}) async {},
          fetchPage:
              (_, __) async => PaginatedResponseDto<RankedMovieListItemDto>(
                items: <RankedMovieListItemDto>[_rankedMovie(1)],
                page: 1,
                pageSize: 24,
                total: 1,
              ),
        );

        await controller.initialize();
        controller.applySubscriptionChange(
          movieNumber: 'ABC-001',
          isSubscribed: true,
        );

        expect(controller.items.single.isSubscribed, isTrue);

        controller.dispose();
      },
    );
  });
}

RankedMovieListItemDto _rankedMovie(int rank) {
  return RankedMovieListItemDto(
    rank: rank,
    javdbId: 'movie-$rank',
    movieNumber: 'ABC-${rank.toString().padLeft(3, '0')}',
    title: 'Movie $rank',
    coverImage: null,
    releaseDate: DateTime.parse('2024-01-01'),
    durationMinutes: 120,
    heat: 10,
    isSubscribed: false,
    canPlay: true,
  );
}
