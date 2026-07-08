import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_detail_dto.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';

/// 非 JAV 视频条目接口（`/videos`）。
///
/// 与 [MoviesApi] 平行，但裁掉订阅/下载/推荐；列表仅支持关键词 `query` 与 `sort`
/// 排序（后端已移除 videos 域的标签/人物筛选）。
class VideosApi {
  const VideosApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<PaginatedResponseDto<VideoItemListItemDto>> getVideos({
    String? query,
    String? sort,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParameters = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    final trimmedQuery = query?.trim();
    if (trimmedQuery != null && trimmedQuery.isNotEmpty) {
      queryParameters['query'] = trimmedQuery;
    }
    if (sort != null && sort.isNotEmpty) {
      queryParameters['sort'] = sort;
    }

    final response = await _apiClient.get(
      '/videos',
      queryParameters: queryParameters,
    );
    return PaginatedResponseDto<VideoItemListItemDto>.fromJson(
      response,
      VideoItemListItemDto.fromJson,
    );
  }

  Future<VideoItemDetailDto> getVideoDetail({required int videoId}) async {
    final response = await _apiClient.get('/videos/$videoId');
    return VideoItemDetailDto.fromJson(response);
  }

  Future<VideoItemDetailDto> updateVideo({
    required int videoId,
    required VideoItemUpdatePayload payload,
  }) async {
    final response = await _apiClient.patch(
      '/videos/$videoId',
      data: payload.toJson(),
    );
    return VideoItemDetailDto.fromJson(response);
  }

  Future<void> deleteVideo(int videoId) {
    return _apiClient.deleteNoContent('/videos/$videoId');
  }
}
