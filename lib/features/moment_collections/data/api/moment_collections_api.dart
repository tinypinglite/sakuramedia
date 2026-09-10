import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/fetch_all_pages.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/moment_collections/data/dto/moment_collection_dto.dart';

class MomentCollectionsApi {
  const MomentCollectionsApi({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<MomentCollectionDto>> getCollections() async {
    final response = await _apiClient.getList('/moment-collections');
    return response.map(MomentCollectionDto.fromJson).toList(growable: false);
  }

  Future<MomentCollectionDto> createCollection({
    required String name,
    String? description,
  }) async {
    final response = await _apiClient.post(
      '/moment-collections',
      data: <String, dynamic>{
        'name': name.trim(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );
    return MomentCollectionDto.fromJson(response);
  }

  Future<MomentCollectionDto> getCollection({required int collectionId}) async {
    final response = await _apiClient.get('/moment-collections/$collectionId');
    return MomentCollectionDto.fromJson(response);
  }

  Future<MomentCollectionDto> updateCollection({
    required int collectionId,
    required UpdateMomentCollectionPayload payload,
  }) async {
    final response = await _apiClient.patch(
      '/moment-collections/$collectionId',
      data: payload.toJson(),
    );
    return MomentCollectionDto.fromJson(response);
  }

  Future<void> deleteCollection({required int collectionId}) =>
      _apiClient.deleteNoContent('/moment-collections/$collectionId');

  Future<PaginatedResponseDto<MomentCollectionPointDto>> getCollectionPoints({
    required int collectionId,
    int page = 1,
    int pageSize = 50,
  }) async {
    final response = await _apiClient.get(
      '/moment-collections/$collectionId/points',
      queryParameters: <String, dynamic>{'page': page, 'page_size': pageSize},
    );
    return PaginatedResponseDto<MomentCollectionPointDto>.fromJson(
      response,
      MomentCollectionPointDto.fromJson,
    );
  }

  Future<List<MomentCollectionPointDto>> getAllCollectionPoints({
    required int collectionId,
  }) {
    return fetchAllPagesConcurrently<
      MomentCollectionPointDto,
      MomentCollectionPointDto
    >(
      fetchPage: (page) =>
          getCollectionPoints(collectionId: collectionId, page: page),
      extractItems: (response) => response.items,
      pageSize: 50,
      concurrency: 4,
      keyOf: (item) => item.pointId,
    );
  }

  Future<void> addPoint({required int collectionId, required int pointId}) =>
      _apiClient.putNoContent(
        '/moment-collections/$collectionId/points/$pointId',
      );

  Future<void> removePoint({required int collectionId, required int pointId}) =>
      _apiClient.deleteNoContent(
        '/moment-collections/$collectionId/points/$pointId',
      );

  Future<void> setPoints({
    required int collectionId,
    required List<int> pointIds,
  }) => _apiClient.putNoContent(
    '/moment-collections/$collectionId/points',
    data: <String, dynamic>{'point_ids': pointIds},
  );

  Future<List<MomentCollectionSummaryDto>> getPointCollections({
    required int pointId,
  }) async {
    final response = await _apiClient.getList(
      '/media-points/$pointId/collections',
    );
    return response
        .map(MomentCollectionSummaryDto.fromJson)
        .toList(growable: false);
  }
}
