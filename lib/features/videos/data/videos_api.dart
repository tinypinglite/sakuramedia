import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/videos/data/video_item_detail_dto.dart';
import 'package:sakuramedia/features/videos/data/video_item_list_item_dto.dart';

/// 非 JAV 视频条目接口（`/videos`）。
///
/// 与 [MoviesApi] 平行，但裁掉订阅/下载/推荐。注意筛选参数 `tag_id`/`person_id`
/// 是后端 `List[int]` 的**重复 key**（`?tag_id=1&tag_id=2`），不是 movies 的逗号
/// 拼接 `tag_ids`；dio 默认 `ListFormat.multiCompatible` 会把 List 展开成重复 key。
class VideosApi {
  const VideosApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<PaginatedResponseDto<VideoItemListItemDto>> getVideos({
    String? query,
    List<int>? tagIds,
    List<int>? personIds,
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
    if (tagIds != null && tagIds.isNotEmpty) {
      queryParameters['tag_id'] = tagIds;
    }
    if (personIds != null && personIds.isNotEmpty) {
      queryParameters['person_id'] = personIds;
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

  Future<VideoItemDetailDto> createVideo({
    required String title,
    String summary = '',
    DateTime? releaseDate,
    List<int> tagIds = const <int>[],
    List<int> personIds = const <int>[],
  }) async {
    final response = await _apiClient.post(
      '/videos',
      data: <String, dynamic>{
        'title': title.trim(),
        'summary': summary,
        if (releaseDate != null) 'release_date': releaseDate.toIso8601String(),
        'tag_ids': tagIds,
        'person_ids': personIds,
      },
    );
    return VideoItemDetailDto.fromJson(response);
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
