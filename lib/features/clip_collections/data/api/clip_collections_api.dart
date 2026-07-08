import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/fetch_all_pages.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/clip_collections/data/dto/clip_collection_dto.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';

/// 切片合集接口：合集增删改查 + 成员增删与有序重排。
///
/// 对接后端 `/clip-collections` 系列接口，结构对称影片播放列表 `PlaylistsApi`。
class ClipCollectionsApi {
  const ClipCollectionsApi({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// 列出全部合集（按更新时间倒序，后端已排序）。
  Future<List<ClipCollectionDto>> getCollections() async {
    final response = await _apiClient.getList('/clip-collections');
    return response.map(ClipCollectionDto.fromJson).toList(growable: false);
  }

  Future<ClipCollectionDto> createCollection({
    required String name,
    String? description,
  }) async {
    final response = await _apiClient.post(
      '/clip-collections',
      data: <String, dynamic>{
        'name': name.trim(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );
    return ClipCollectionDto.fromJson(response);
  }

  Future<ClipCollectionDto> getCollectionDetail({
    required int collectionId,
  }) async {
    final response = await _apiClient.get('/clip-collections/$collectionId');
    return ClipCollectionDto.fromJson(response);
  }

  Future<ClipCollectionDto> updateCollection({
    required int collectionId,
    required UpdateClipCollectionPayload payload,
  }) async {
    final response = await _apiClient.patch(
      '/clip-collections/$collectionId',
      data: payload.toJson(),
    );
    return ClipCollectionDto.fromJson(response);
  }

  Future<void> deleteCollection({required int collectionId}) {
    return _apiClient.deleteNoContent('/clip-collections/$collectionId');
  }

  /// 合集内切片（按 `position` 升序，分页）。
  Future<PaginatedResponseDto<ClipCollectionClipItemDto>> getCollectionClips({
    required int collectionId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiClient.get(
      '/clip-collections/$collectionId/clips',
      queryParameters: <String, dynamic>{'page': page, 'page_size': pageSize},
    );
    return PaginatedResponseDto<ClipCollectionClipItemDto>.fromJson(
      response,
      ClipCollectionClipItemDto.fromJson,
    );
  }

  /// 拉取合集**全部**切片：并发翻页（见 [fetchAllPagesConcurrently]）。详情页与连播页
  /// 共用，替代各自手写的串行翻页循环，墙钟从 O(N) 降到 ~O(N/并发)。并发期间集合被并发
  /// 增删导致页窗口错位时，按 `clipId` 去重避免重复切片进播放列表。
  Future<List<MediaClipDto>> getAllCollectionClips({
    required int collectionId,
    int pageSize = 50,
    int concurrency = 6,
  }) {
    return fetchAllPagesConcurrently<MediaClipDto, ClipCollectionClipItemDto>(
      fetchPage:
          (page) => getCollectionClips(
            collectionId: collectionId,
            page: page,
            pageSize: pageSize,
          ),
      extractItems: (response) => response.items.map((item) => item.clip),
      pageSize: pageSize,
      concurrency: concurrency,
      keyOf: (clip) => clip.clipId,
    );
  }

  /// 把切片追加到合集末尾（后端幂等，已存在则无副作用）。
  Future<void> addClipToCollection({
    required int collectionId,
    required int clipId,
  }) {
    return _apiClient.putNoContent(
      '/clip-collections/$collectionId/clips/$clipId',
    );
  }

  Future<void> removeClipFromCollection({
    required int collectionId,
    required int clipId,
  }) {
    return _apiClient.deleteNoContent(
      '/clip-collections/$collectionId/clips/$clipId',
    );
  }

  /// 全量有序设置合集成员：既覆盖重排也覆盖批量设置成员（后端按此列表重新编号 position）。
  Future<void> setCollectionClips({
    required int collectionId,
    required List<int> clipIds,
  }) {
    return _apiClient.putNoContent(
      '/clip-collections/$collectionId/clips',
      data: <String, dynamic>{'clip_ids': clipIds},
    );
  }
}
