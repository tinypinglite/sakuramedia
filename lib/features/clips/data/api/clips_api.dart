import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_thumbnail_dto.dart';

class ClipsApi {
  const ClipsApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// 创建切片同步切片，后端 ffmpeg 墙钟超时默认 120s，这里给足余量覆盖它，
  /// 避免前端默认 30s 提前超时。
  static const Duration _createTimeout = Duration(seconds: 130);

  /// 在某媒体上圈选两张缩略图创建切片。
  ///
  /// 新建返回 201、命中去重返回 200，两者都带 `MediaClipResource` 响应体。
  Future<MediaClipDto> createClip({
    required int mediaId,
    required int startThumbnailId,
    required int endThumbnailId,
    String title = '',
  }) async {
    final response = await _apiClient.post(
      '/media/$mediaId/clips',
      data: <String, dynamic>{
        'start_thumbnail_id': startThumbnailId,
        'end_thumbnail_id': endThumbnailId,
        'title': title.trim(),
      },
      receiveTimeout: _createTimeout,
    );
    return MediaClipDto.fromJson(response);
  }

  /// 我的切片（全局分页）。
  Future<PaginatedResponseDto<MediaClipDto>> getMyClips({
    int page = 1,
    int pageSize = 20,
    String sort = 'created_at:desc',
  }) async {
    final response = await _apiClient.get(
      '/media-clips',
      queryParameters: <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        'sort': sort,
      },
    );
    return PaginatedResponseDto<MediaClipDto>.fromJson(
      response,
      MediaClipDto.fromJson,
    );
  }

  /// 列出某媒体的切片（创建时间倒序）。
  Future<List<MediaClipDto>> getClipsByMedia({required int mediaId}) async {
    final response = await _apiClient.getList('/media/$mediaId/clips');
    return response.map(MediaClipDto.fromJson).toList(growable: false);
  }

  /// 按番号拉取影片的切片（命中后端 `MediaClip.movie_number` 快照列）。
  ///
  /// Media 源删除后 `movie_number` 仍保留，故影片仍可查到其切片。
  Future<List<MediaClipDto>> getClipsByMovieNumber({
    required String movieNumber,
    int limit = 30,
  }) async {
    final response = await _apiClient.get(
      '/media-clips',
      queryParameters: <String, dynamic>{
        'movie_number': movieNumber,
        'limit': limit,
      },
    );
    final items = (response['items'] as List<dynamic>?)
            ?.map(
              (dynamic e) =>
                  MediaClipDto.fromJson(e as Map<String, dynamic>),
            )
            .toList(growable: false) ??
        <MediaClipDto>[];
    return items;
  }

  /// 切片详情：含 `previewFrames`（悬停预览）与 `collections`（所属合集回显）。
  Future<MediaClipDto> getClipDetail({required int clipId}) async {
    final response = await _apiClient.get('/media-clips/$clipId');
    return MediaClipDto.fromJson(response);
  }

  Future<MediaClipDto> updateClipTitle({
    required int clipId,
    required String title,
  }) async {
    final response = await _apiClient.patch(
      '/media-clips/$clipId',
      data: <String, dynamic>{'title': title.trim()},
    );
    return MediaClipDto.fromJson(response);
  }

  Future<void> deleteClip({required int clipId}) {
    return _apiClient.deleteNoContent('/media-clips/$clipId');
  }

  /// 切片区间内的关键帧缩略图（按切片自身时间轴的相对 offset 升序）。
  ///
  /// 供合集连播页右侧「整部合集」关键帧面板拉单集的帧序列；来源媒体已删的切片返回空。
  Future<List<MediaClipThumbnailDto>> getClipThumbnails({
    required int clipId,
  }) async {
    final response = await _apiClient.getList('/media-clips/$clipId/thumbnails');
    return response
        .map(MediaClipThumbnailDto.fromJson)
        .toList(growable: false);
  }
}
