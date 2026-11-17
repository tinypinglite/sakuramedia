import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_thumbnail_provider.dart';

void main() {
  test('缩略图首次加载完成前按骨架处理', () {
    const initial = MovieDetailThumbnailState.initial;
    expect(initial.shouldShowInitialSkeleton, isTrue);
    expect(
      initial.copyWith(hasLoaded: true).shouldShowInitialSkeleton,
      isFalse,
    );
    expect(
      initial
          .copyWith(hasLoaded: true, isLoading: true)
          .shouldShowInitialSkeleton,
      isTrue,
    );
  });
}
