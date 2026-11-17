import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/movies/data/dto/thumbnails/movie_media_thumbnail_dto.dart';

part 'cast_remote_thumbnails_provider.g.dart';

/// 遥控页的缩略图列表（与播放器同源数据）。
@riverpod
Future<List<MovieMediaThumbnailDto>> castRemoteThumbnails(
  Ref ref, {
  required int mediaId,
}) {
  return ref.watch(mediaApiProvider).getMediaThumbnails(mediaId: mediaId);
}
