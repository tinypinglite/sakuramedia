import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';

/// 热门女优的新片推荐；影片卡片字段直接复用 [MovieListItemDto]。
class HotActressReleaseMovieDto {
  const HotActressReleaseMovieDto({
    required this.movie,
    required this.hotActressName,
  });

  final MovieListItemDto movie;
  final String hotActressName;

  HotActressReleaseMovieDto copyWith({MovieListItemDto? movie}) {
    return HotActressReleaseMovieDto(
      movie: movie ?? this.movie,
      hotActressName: hotActressName,
    );
  }

  factory HotActressReleaseMovieDto.fromJson(Map<String, dynamic> json) {
    final hotActress = json['hot_actress'];
    return HotActressReleaseMovieDto(
      movie: MovieListItemDto.fromJson(json),
      hotActressName: hotActress is Map
          ? hotActress['name'] as String? ?? ''
          : '',
    );
  }
}
