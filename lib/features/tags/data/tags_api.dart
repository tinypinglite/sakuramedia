import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/tags/data/tag_list_item_dto.dart';

class TagsApi {
  const TagsApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// 获取全部标签（含每标签影片数）。
  ///
  /// [query] 为标签名称模糊匹配，空白串后端会返回 422，故仅在非空时下发。
  /// [sort] 默认按影片数降序，便于优先展示热门标签。
  Future<List<TagListItemDto>> getTags({
    String? query,
    String sort = 'movie_count:desc',
  }) async {
    final queryParameters = <String, dynamic>{'sort': sort};
    final trimmed = query?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      queryParameters['query'] = trimmed;
    }

    final response = await _apiClient.getList(
      '/tags',
      queryParameters: queryParameters,
    );
    return response.map(TagListItemDto.fromJson).toList(growable: false);
  }
}
