import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/media/data/duplicate_media_group_dto.dart';
import 'package:sakuramedia/features/media/data/invalid_media_dto.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/data/media_point_dto.dart';
import 'package:sakuramedia/features/media/data/media_point_list_item_dto.dart';

class MediaApi {
  const MediaApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// `GET /media`：跨 JAV / videos 域的全局媒体列表。
  ///
  /// - [kind] 传 `all` / `jav` / `video`，`null` 走后端默认（`all`）。
  /// - [libraryId] 指定媒体库过滤，null 时不加参数。
  /// - [actorIds] 订阅女优 OR 筛选，会拼成逗号分隔字符串下发。
  /// - [sort] 例如 `heat:desc`、`file_size_bytes:desc`，`null` 时后端默认 `created_at:desc`。
  Future<PaginatedResponseDto<MediaListItemDto>> getMediaList({
    int page = 1,
    int pageSize = 20,
    String? kind,
    int? libraryId,
    List<int>? actorIds,
    String? thumbnailGenerationState,
    String? sort,
  }) async {
    final queryParameters = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (kind != null && kind.isNotEmpty) {
      queryParameters['kind'] = kind;
    }
    if (libraryId != null) {
      queryParameters['library_id'] = libraryId;
    }
    if (actorIds != null && actorIds.isNotEmpty) {
      queryParameters['actor_ids'] = actorIds.join(',');
    }
    if (thumbnailGenerationState != null &&
        thumbnailGenerationState.isNotEmpty) {
      queryParameters['thumbnail_generation_state'] = thumbnailGenerationState;
    }
    if (sort != null && sort.isNotEmpty) {
      queryParameters['sort'] = sort;
    }
    final response = await _apiClient.get(
      '/media',
      queryParameters: queryParameters,
    );
    return PaginatedResponseDto<MediaListItemDto>.fromJson(
      response,
      MediaListItemDto.fromJson,
    );
  }

  Future<PaginatedResponseDto<MediaPointListItemDto>> getGlobalMediaPoints({
    int page = 1,
    int pageSize = 20,
    String sort = 'created_at:desc',
    String? kind,
  }) async {
    final queryParameters = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
      'sort': sort,
    };
    if (kind != null && kind.isNotEmpty) {
      queryParameters['kind'] = kind;
    }
    final response = await _apiClient.get(
      '/media-points',
      queryParameters: queryParameters,
    );
    return PaginatedResponseDto<MediaPointListItemDto>.fromJson(
      response,
      MediaPointListItemDto.fromJson,
    );
  }

  Future<List<MediaPointDto>> getMediaPoints({required int mediaId}) async {
    final response = await _apiClient.getList('/media/$mediaId/points');
    return response.map(MediaPointDto.fromJson).toList(growable: false);
  }

  Future<PaginatedResponseDto<InvalidMediaDto>> getInvalidMedia({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiClient.get(
      '/media/invalid',
      queryParameters: <String, dynamic>{'page': page, 'page_size': pageSize},
    );
    return PaginatedResponseDto<InvalidMediaDto>.fromJson(
      response,
      InvalidMediaDto.fromJson,
    );
  }

  Future<PaginatedResponseDto<DuplicateMediaGroupDto>> getDuplicateMediaGroups({
    required String kind,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiClient.get(
      '/media/duplicates',
      queryParameters: <String, dynamic>{
        'kind': kind,
        'page': page,
        'page_size': pageSize,
      },
    );
    return PaginatedResponseDto<DuplicateMediaGroupDto>.fromJson(
      response,
      DuplicateMediaGroupDto.fromJson,
    );
  }

  Future<MediaPointDto> createMediaPoint({
    required int mediaId,
    required int thumbnailId,
  }) async {
    final response = await _apiClient.post(
      '/media/$mediaId/points',
      data: <String, dynamic>{'thumbnail_id': thumbnailId},
    );
    return MediaPointDto.fromJson(response);
  }

  Future<void> deleteMediaPoint({required int mediaId, required int pointId}) {
    return _apiClient.deleteNoContent('/media/$mediaId/points/$pointId');
  }

  Future<void> deleteMedia({required int mediaId}) {
    return _apiClient.deleteNoContent('/media/$mediaId');
  }
}
