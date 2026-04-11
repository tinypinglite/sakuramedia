import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/hot_reviews/data/hot_review_list_item_dto.dart';
import 'package:sakuramedia/features/hot_reviews/data/hot_review_period.dart';
import 'package:sakuramedia/features/hot_reviews/presentation/paged_hot_review_controller.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PagedHotReviewController', () {
    test('refresh replaces first page items', () async {
      var cycle = 0;
      final controller = PagedHotReviewController(
        fetchPage: (page, pageSize, period) async {
          cycle += 1;
          expect(period, HotReviewPeriod.weekly);
          if (cycle == 1) {
            return PaginatedResponseDto<HotReviewListItemDto>(
              items: <HotReviewListItemDto>[_hotReview(1)],
              page: 1,
              pageSize: 20,
              total: 2,
            );
          }
          return PaginatedResponseDto<HotReviewListItemDto>(
            items: <HotReviewListItemDto>[_hotReview(99)],
            page: 1,
            pageSize: 20,
            total: 1,
          );
        },
      );

      await controller.initialize();
      await controller.refresh();

      expect(controller.items.single.reviewId, 99);
      expect(controller.currentPage, 1);
      expect(controller.total, 1);
      expect(controller.hasMore, isFalse);

      controller.dispose();
    });

    test('refresh rethrows and keeps existing items on failure', () async {
      var cycle = 0;
      final controller = PagedHotReviewController(
        fetchPage: (page, pageSize, period) async {
          cycle += 1;
          if (cycle == 1) {
            return PaginatedResponseDto<HotReviewListItemDto>(
              items: <HotReviewListItemDto>[_hotReview(1)],
              page: 1,
              pageSize: 20,
              total: 2,
            );
          }
          throw Exception('refresh failed');
        },
      );

      await controller.initialize();

      await expectLater(controller.refresh(), throwsException);

      expect(controller.items.single.reviewId, 1);
      expect(controller.currentPage, 1);
      expect(controller.total, 2);

      controller.dispose();
    });
  });
}

HotReviewListItemDto _hotReview(int reviewId) {
  return HotReviewListItemDto(
    rank: 1,
    reviewId: reviewId,
    score: 5,
    content: 'Review $reviewId',
    createdAt: DateTime.parse('2026-03-12T10:00:00Z'),
    username: 'user',
    likeCount: 10,
    watchCount: 20,
    movie: MovieListItemDto(
      javdbId: 'movie-$reviewId',
      movieNumber: 'ABC-${reviewId.toString().padLeft(3, '0')}',
      title: 'Movie $reviewId',
      coverImage: null,
      releaseDate: DateTime.parse('2024-01-01'),
      durationMinutes: 120,
      heat: 8,
      isSubscribed: false,
      canPlay: true,
    ),
  );
}
