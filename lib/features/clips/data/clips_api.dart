import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/clips/data/media_clip_dto.dart';

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
}
