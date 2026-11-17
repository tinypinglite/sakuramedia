import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/movies/data/dto/rating/movie_rating_dto.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';

part 'movie_rating_provider.g.dart';

/// 单部影片的个人评分；写入/删除后就地更新状态并刷新「我的评分」列表。
@Riverpod(retry: kNoAsyncNotifierRetry)
class MovieRating extends _$MovieRating {
  @override
  Future<MovieRatingDto> build(String movieNumber) {
    return ref.read(moviesApiProvider).getMovieRating(movieNumber: movieNumber);
  }

  Future<MovieRatingDto> save(Map<int, int> values) async {
    final rating = await ref
        .read(moviesApiProvider)
        .saveMovieRating(movieNumber: movieNumber, values: values);
    state = AsyncData(rating);
    ref.invalidate(movieSummaryProvider(MovieSummaryScope.ratedList));
    return rating;
  }

  Future<void> delete() async {
    await ref.read(moviesApiProvider).deleteMovieRating(movieNumber);
    state = AsyncData(MovieRatingDto(movieNumber: movieNumber, rated: false));
    ref.invalidate(movieSummaryProvider(MovieSummaryScope.ratedList));
  }
}
