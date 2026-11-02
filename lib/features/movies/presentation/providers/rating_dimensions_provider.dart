import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/movies/data/dto/rating/rating_dimension_dto.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';

part 'rating_dimensions_provider.g.dart';

/// 全局评分维度；维度变更会影响所有影片的总分，写入后重拉并失效已评分列表。
@Riverpod(retry: kNoAsyncNotifierRetry)
class RatingDimensions extends _$RatingDimensions {
  @override
  Future<List<RatingDimensionDto>> build() {
    return ref.read(moviesApiProvider).getRatingDimensions();
  }

  Future<void> create({required String name, int maxValue = 5}) async {
    await ref
        .read(moviesApiProvider)
        .createRatingDimension(name: name, maxValue: maxValue);
    await _reload();
  }

  Future<void> edit({
    required int dimensionId,
    required String name,
    required double weight,
    int? maxValue,
  }) async {
    await ref
        .read(moviesApiProvider)
        .updateRatingDimension(
          dimensionId: dimensionId,
          name: name,
          weight: weight,
          maxValue: maxValue,
        );
    await _reload();
  }

  Future<void> delete(int dimensionId) async {
    await ref.read(moviesApiProvider).deleteRatingDimension(dimensionId);
    await _reload();
  }

  Future<void> _reload() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // 列表自身的错误态由页面展示，写入成功后不把失败抛回弹窗。
    }
    ref.invalidate(movieSummaryProvider(MovieSummaryScope.ratedList));
  }
}
