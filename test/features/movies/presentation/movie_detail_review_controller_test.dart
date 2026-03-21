import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/data/movie_review_dto.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_review_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<String, Object?>> requests;

  setUp(() {
    requests = <Map<String, Object?>>[];
  });

  test('loadInitial fetches first page using default hotly sort', () async {
    final controller = MovieDetailReviewController(
      movieNumber: 'ABC-001',
      fetchMovieReviews: ({
        required movieNumber,
        required page,
        required pageSize,
        required sort,
      }) async {
        requests.add(<String, Object?>{
          'movieNumber': movieNumber,
          'page': page,
          'pageSize': pageSize,
          'sort': sort.apiValue,
        });
        return _buildReviews(count: 2, prefix: 'hot');
      },
    );
    addTearDown(controller.dispose);

    await controller.loadInitial();

    expect(requests, hasLength(1));
    expect(requests.single['movieNumber'], 'ABC-001');
    expect(requests.single['page'], 1);
    expect(requests.single['pageSize'], 20);
    expect(requests.single['sort'], 'hotly');
    expect(controller.items, hasLength(2));
    expect(controller.initialErrorMessage, isNull);
  });

  test('setSort reloads first page with the selected sort', () async {
    final controller = MovieDetailReviewController(
      movieNumber: 'ABC-001',
      fetchMovieReviews: ({
        required movieNumber,
        required page,
        required pageSize,
        required sort,
      }) async {
        requests.add(<String, Object?>{
          'movieNumber': movieNumber,
          'page': page,
          'pageSize': pageSize,
          'sort': sort.apiValue,
        });
        return _buildReviews(count: 1, prefix: sort.apiValue);
      },
    );
    addTearDown(controller.dispose);

    await controller.loadInitial();
    await controller.setSort(MovieReviewSort.recently);

    expect(requests, hasLength(2));
    expect(requests.first['sort'], 'hotly');
    expect(requests.last['sort'], 'recently');
    expect(controller.sort, MovieReviewSort.recently);
    expect(controller.items.single.content, contains('recently'));
  });

  test('loadMore appends next page when request succeeds', () async {
    final controller = MovieDetailReviewController(
      movieNumber: 'ABC-001',
      fetchMovieReviews: ({
        required movieNumber,
        required page,
        required pageSize,
        required sort,
      }) async {
        requests.add(<String, Object?>{
          'page': page,
          'pageSize': pageSize,
          'sort': sort.apiValue,
        });
        if (page == 1) {
          return _buildReviews(count: 20, prefix: 'p1');
        }
        return _buildReviews(count: 2, prefix: 'p2');
      },
    );
    addTearDown(controller.dispose);

    await controller.loadInitial();
    await controller.loadMore();

    expect(requests.map((item) => item['page']), <Object?>[1, 2]);
    expect(controller.items, hasLength(22));
    expect(controller.hasNextPage, isFalse);
    expect(controller.loadMoreErrorMessage, isNull);
  });

  test('loadMore failure keeps existing reviews and allows retry', () async {
    var failLoadMore = true;
    final controller = MovieDetailReviewController(
      movieNumber: 'ABC-001',
      fetchMovieReviews: ({
        required movieNumber,
        required page,
        required pageSize,
        required sort,
      }) async {
        requests.add(<String, Object?>{
          'page': page,
          'pageSize': pageSize,
          'sort': sort.apiValue,
        });
        if (page == 1) {
          return _buildReviews(count: 20, prefix: 'p1');
        }
        if (failLoadMore) {
          throw Exception('boom');
        }
        return _buildReviews(count: 1, prefix: 'p2');
      },
    );
    addTearDown(controller.dispose);

    await controller.loadInitial();
    final firstPageItems = List<MovieReviewDto>.from(controller.items);

    await controller.loadMore();
    expect(controller.items, firstPageItems);
    expect(controller.loadMoreErrorMessage, isNotNull);

    failLoadMore = false;
    await controller.loadMore();

    expect(requests.map((item) => item['page']), <Object?>[1, 2, 2]);
    expect(controller.items, hasLength(21));
    expect(controller.loadMoreErrorMessage, isNull);
  });
}

List<MovieReviewDto> _buildReviews({
  required int count,
  required String prefix,
}) {
  return List<MovieReviewDto>.generate(count, (index) {
    return MovieReviewDto(
      id: index + 1,
      score: 5,
      content: '$prefix-review-${index + 1}',
      createdAt: DateTime.parse('2026-03-10T08:00:00Z'),
      username: '$prefix-user',
      likeCount: 10 + index,
      watchCount: 20 + index,
    );
  });
}
