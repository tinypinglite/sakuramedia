import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/videos/data/video_collection_dto.dart';

/// 视频合集接口（`/video-collections`）。合集列表与成员均为非分页 `List`。
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

  Future<List<VideoCollectionItemDto>> getCollectionItems({
    required int collectionId,
  }) async {
    final response = await _apiClient.getList(
      '/video-collections/$collectionId/items',
    );
    return response
        .map(VideoCollectionItemDto.fromJson)
        .toList(growable: false);
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
  /// `postNoContent`；调用方在成功后保留本地顺序、失败时回滚并重载。
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
