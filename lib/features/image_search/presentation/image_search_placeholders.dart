import 'package:sakuramedia/features/image_search/data/image_search_result_item_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// 图搜结果首载占位：真实结果卡 + 空图片地址，供 `AppSkeletonizer` 灰化。
List<ImageSearchResultItemDto> imageSearchResultPlaceholders({int count = 8}) {
  return List<ImageSearchResultItemDto>.generate(
    count,
    (index) => ImageSearchResultItemDto(
      thumbnailId: index + 1,
      mediaId: 0,
      movieId: 0,
      movieNumber: BoneMock.words(1),
      offsetSeconds: 0,
      score: 0.9,
      image: const MovieImageDto(id: 0, origin: ''),
    ),
    growable: false,
  );
}
