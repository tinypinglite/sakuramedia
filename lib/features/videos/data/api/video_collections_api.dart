import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/fetch_all_pages.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';

/// 视频合集接口（`/video-collections`）。合集列表为非分页 `List`；成员端点已分页
/// （`page`/`page_size`），万级成员合集靠分页避免单请求超时。
class VideoCollectionsApi {
  const VideoCollectionsApi({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<VideoCollectionDto>> getCollections() async {
    final response = await _apiClient.getList('/video-collections');
    return response
        .map(VideoCollectionDto.fromJson)
        .toList(growable: false);
  }

  Future<VideoCollectionDto> createCollection({
    required String name,
    String description = '',
  }) async {
    final response = await _apiClient.post(
      '/video-collections',
      data: <String, dynamic>{'name': name.trim(), 'description': description},
    );
    return VideoCollectionDto.fromJson(response);
  }

  Future<VideoCollectionDto> getCollection({required int collectionId}) async {
    final response = await _apiClient.get('/video-collections/$collectionId');
    return VideoCollectionDto.fromJson(response);
  }

  Future<VideoCollectionDto> updateCollection({
    required int collectionId,
    required VideoCollectionUpdatePayload payload,
  }) async {
    final response = await _apiClient.patch(
      '/video-collections/$collectionId',
      data: payload.toJson(),
    );
    return VideoCollectionDto.fromJson(response);
  }

  Future<void> deleteCollection(int collectionId) {
    return _apiClient.deleteNoContent('/video-collections/$collectionId');
  }

  /// 分页拉取合集成员。[sort] 形如 `field:direction`：
  /// `position`(默认手动顺序) / `created_at` / `title` / `duration` / `file_size`；
  /// 传 `null` 时后端按 `position:asc` 返回，与拖拽重排的手动顺序一致。
  ///
  /// [includePlayUrl] 为 true 时，后端为每个成员内联「首个媒体」的签名播放地址
  /// （`playUrl`），供连播页直接组装播放列表，免逐集拉详情。
  Future<PaginatedResponseDto<VideoCollectionItemDto>> getCollectionItems({
    required int collectionId,
    String? sort,
    int page = 1,
    int pageSize = 100,
    bool includePlayUrl = false,
  }) async {
    final queryParameters = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (sort != null && sort.isNotEmpty) {
      queryParameters['sort'] = sort;
    }
    if (includePlayUrl) {
      queryParameters['include_play_url'] = true;
    }
    final response = await _apiClient.get(
      '/video-collections/$collectionId/items',
      queryParameters: queryParameters,
    );
    return PaginatedResponseDto<VideoCollectionItemDto>.fromJson(
      response,
      VideoCollectionItemDto.fromJson,
    );
  }

  /// 拉取合集**全部**成员：并发翻页（见 [fetchAllPagesConcurrently]），墙钟从串行的
  /// O(N) 降到 ~O(N/并发)。详情页/连播页都用它替代旧的一次性全返。并发期间集合被并发
  /// 增删导致页窗口错位时，按 `itemId` 去重避免重复成员进播放列表。
  Future<List<VideoCollectionItemDto>> getAllCollectionItems({
    required int collectionId,
    String? sort,
    bool includePlayUrl = false,
    int pageSize = 100,
    int concurrency = 6,
  }) {
    return fetchAllPagesConcurrently<
      VideoCollectionItemDto,
      VideoCollectionItemDto
    >(
      fetchPage:
          (page) => getCollectionItems(
            collectionId: collectionId,
            sort: sort,
            page: page,
            pageSize: pageSize,
            includePlayUrl: includePlayUrl,
          ),
      extractItems: (response) => response.items,
      pageSize: pageSize,
      concurrency: concurrency,
      keyOf: (item) => item.itemId,
    );
  }

  Future<void> addCollectionItem({
    required int collectionId,
    required int videoItemId,
  }) {
    return _apiClient.postNoContent(
      '/video-collections/$collectionId/items',
      data: <String, dynamic>{'video_item_id': videoItemId},
    );
  }

  Future<void> removeCollectionItem({
    required int collectionId,
    required int itemId,
  }) {
    return _apiClient.deleteNoContent(
      '/video-collections/$collectionId/items/$itemId',
    );
  }

  /// 按 [orderedItemIds] 重写成员 `position`。须恰好覆盖全部成员，否则后端返回 422。
  ///
  /// 端点返回重排后的成员列表，但前端走乐观重排、不消费返回体，故用
  /// `postNoContent`；调用方在成功后保留本地顺序、失败时回滚到提交前的本地顺序。
  Future<void> reorderCollectionItems({
    required int collectionId,
    required List<int> orderedItemIds,
  }) {
    return _apiClient.postNoContent(
      '/video-collections/$collectionId/items/reorder',
      data: <String, dynamic>{'ordered_item_ids': orderedItemIds},
    );
  }
}
