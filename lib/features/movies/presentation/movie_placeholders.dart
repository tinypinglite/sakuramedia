import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_review_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_interaction_filter_options_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/player/movie_subtitle_dto.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// 影片相关加载态占位数据：真实 DTO + [BoneMock] 文案，
/// 供 `AppSkeletonizer` 渲染与真实卡片 / 药丸同形的静态骨架。

List<MovieListItemDto> movieListItemPlaceholders({int count = 8}) {
  return List<MovieListItemDto>.generate(
    count,
    (index) => MovieListItemDto(
      // 卡片 key 由 movieNumber 派生，占位项必须彼此唯一。
      id: -1 - index,
      movieNumber: 'ABC-${(index + 1).toString().padLeft(3, '0')}',
      title: BoneMock.words(3),
      coverImage: null,
      releaseDate: DateTime(2026, 1, 1),
      durationMinutes: 120,
      heat: 100,
      isSubscribed: false,
      canPlay: false,
    ),
    growable: false,
  );
}

/// 影片详情页加载态占位：真实 DTO + [BoneMock] 文案，封面 / 图集 / 演职员
/// 一律为空，不触发网络请求；供详情页渲染真实布局后由 `AppSkeletonizer` 灰化。
MovieDetailDto movieDetailPlaceholder() {
  return MovieDetailDto(
    movieNumber: 'ABC-001',
    title: BoneMock.words(3),
    seriesName: '',
    makerName: '',
    directorName: '',
    coverImage: null,
    releaseDate: null,
    durationMinutes: 120,
    interactionStats: const <String, num>{
      'score': 4.5,
      'watched_count': 12,
    },
    statsSource: 'legacy:host',
    heat: 0,
    isCollection: false,
    isSubscribed: false,
    canPlay: false,
    summary: BoneMock.paragraph,
    thinCoverImage: null,
    plotImages: const <MovieImageDto>[],
    actors: const <MovieActorDto>[],
    tags: const <MovieTagDto>[],
    mediaItems: const <MovieMediaItemDto>[],
    playlists: const <MoviePlaylistSummaryDto>[],
  );
}

List<MovieReviewDto> movieReviewPlaceholders({int count = 3}) {
  return List<MovieReviewDto>.generate(
    count,
    (index) => MovieReviewDto(
      id: -1 - index,
      score: 4,
      content: BoneMock.paragraph,
      createdAt: DateTime(2026, 1, 1),
      username: BoneMock.words(1),
      likeCount: 3,
      watchCount: 12,
    ),
    growable: false,
  );
}

List<MovieSubtitleItemDto> movieSubtitlePlaceholders({int count = 3}) {
  return List<MovieSubtitleItemDto>.generate(
    count,
    (index) => MovieSubtitleItemDto(
      subtitleId: -1 - index,
      fileName: BoneMock.words(2),
      createdAt: null,
      url: '',
    ),
    growable: false,
  );
}

/// 互动数筛选范围加载态占位：六个指标都给正数上限，
/// 让真实滑块分节全部渲染出来，由 `AppSkeletonizer` 灰化并屏蔽交互。
MovieInteractionFilterOptionsDto movieInteractionFilterOptionsPlaceholder() {
  return const MovieInteractionFilterOptionsDto(
    movieCount: 0,
    heat: MovieInteractionDistributionDto(p999: 10000, max: 20000),
    heatVersion: 'host:v6',
  );
}

/// 发行年份加载态占位：标签带影片数，宽度与真实年份药丸接近。
List<MovieFilterYearOption> movieFilterYearPlaceholders({int count = 10}) {
  final latestYear = DateTime.now().year;
  return List<MovieFilterYearOption>.generate(
    count,
    (index) => MovieFilterYearOption(year: latestYear - index, movieCount: 12),
    growable: false,
  );
}
