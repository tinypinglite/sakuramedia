import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/features/videos/data/video_item_detail_dto.dart';

/// 把 [VideoItemDetailDto] 适配成 [MovieDetailDto]，仅为复用泛化后的
/// `MoviePlayerController`（它只消费 `mediaItems`）。其余 JAV 专属字段填中性默认值。
///
/// 这样既复用了同一套播放底座，又无需物理搬迁被 28 个文件引用的媒体 DTO 族。
MovieDetailDto adaptVideoDetailToMovieDetail(VideoItemDetailDto detail) {
  return MovieDetailDto(
    javdbId: '',
    movieNumber: 'video-${detail.id}',
    title: detail.title,
    titleZh: '',
    seriesId: null,
    seriesName: '',
    makerName: '',
    directorName: '',
    coverImage: detail.coverImage,
    releaseDate: detail.releaseDate,
    durationMinutes: 0,
    score: 0,
    heat: 0,
    watchedCount: 0,
    wantWatchCount: 0,
    commentCount: 0,
    scoreNumber: 0,
    isCollection: false,
    isSubscribed: false,
    canPlay: detail.canPlay,
    summary: detail.summary,
    descZh: '',
    desc: '',
    thinCoverImage: null,
    plotImages: const <MovieImageDto>[],
    actors: const <MovieActorDto>[],
    tags: detail.tags,
    mediaItems: detail.mediaItems,
    playlists: const <MoviePlaylistSummaryDto>[],
  );
}
