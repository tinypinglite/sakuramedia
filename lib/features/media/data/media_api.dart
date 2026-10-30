import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/media/data/duplicate_media_group_dto.dart';
import 'package:sakuramedia/features/media/data/invalid_media_dto.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/data/media_point_dto.dart';
import 'package:sakuramedia/features/media/data/media_point_list_item_dto.dart';
import 'package:sakuramedia/features/media/data/media_transfer_dto.dart';
import 'package:sakuramedia/features/media/data/multi_version_movie_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/thumbnails/movie_media_thumbnail_dto.dart';

class MediaApi {
  const MediaApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// `GET /media`：跨 JAV / videos 域的全局媒体列表。
  ///
  /// - [kind] 传 `all` / `jav` / `video`，`null` 走后端默认（`all`）。
  /// - [libraryId] 指定媒体库过滤，null 时不加参数。
  /// - [actorIds] 订阅女优 OR 筛选，会拼成逗号分隔字符串下发。
  /// - [search] 按文件名做大小写不敏感的子串过滤，空串不搜索。
  /// - [sort] 例如 `heat:desc`、`file_size_bytes:desc`，`null` 时后端默认 `created_at:desc`。
  Future<PaginatedResponseDto<MediaListItemDto>> getMediaList({
    int page = 1,
    int pageSize = 20,
    String? kind,
    int? libraryId,
    List<int>? actorIds,
    String? search,
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
    final normalizedSearch = search?.trim() ?? '';
    if (normalizedSearch.isNotEmpty) {
      queryParameters['search'] = normalizedSearch;
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

  /// `POST /media/thumbnails/reset`。
  ///
  /// [force] 为 `false` 时只把「生成失败」重新排队；为 `true` 时删除已有缩略图
  /// 产物后重新生成（生成完成前这些媒体的缩略图不可用）。
  Future<int> resetMediaThumbnails({
    required List<int> mediaIds,
    bool force = false,
  }) async {
    final response = await _apiClient.post(
      '/media/thumbnails/reset',
      data: <String, dynamic>{'media_ids': mediaIds, 'force': force},
    );
    return asInt(response['reset_count']);
  }

  Future<PaginatedResponseDto<MediaPointListItemDto>> getGlobalMediaPoints({
    int page = 1,
    int pageSize = 20,
    String sort = 'created_at:desc',
    String? kind,
    String? keyword,
    int? excludeCollectionId,
  }) async {
    final queryParameters = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
      'sort': sort,
    };
    if (kind != null && kind.isNotEmpty) {
      queryParameters['kind'] = kind;
    }
    final normalizedKeyword = keyword?.trim() ?? '';
    if (normalizedKeyword.isNotEmpty) {
      queryParameters['keyword'] = normalizedKeyword;
    }
    if (excludeCollectionId != null) {
      queryParameters['exclude_collection_id'] = excludeCollectionId;
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

  Future<List<MovieMediaThumbnailDto>> getMediaThumbnails({
    required int mediaId,
  }) async {
    final response = await _apiClient.getList('/media/$mediaId/thumbnails');
    return response
        .map(MovieMediaThumbnailDto.fromJson)
        .toList(growable: false);
  }

  Future<MovieMediaProgressDto> updateMediaProgress({
    required int mediaId,
    required int positionSeconds,
  }) async {
    final response = await _apiClient.put(
      '/media/$mediaId/progress',
      data: <String, dynamic>{'position_seconds': positionSeconds},
    );
    return MovieMediaProgressDto.fromJson(response);
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

  Future<PaginatedResponseDto<MultiVersionMovieDto>> getMultiVersionMovies({
    int page = 1,
    int pageSize = 20,
    bool includeVr = false,
    bool includeFc2 = false,
  }) async {
    final response = await _apiClient.get(
      '/media/multi-version-movies',
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        'include_vr': includeVr,
        'include_fc2': includeFc2,
      },
    );
    return PaginatedResponseDto<MultiVersionMovieDto>.fromJson(
      response,
      MultiVersionMovieDto.fromJson,
    );
  }

  Future<MediaPointDto> createMediaPoint({
    required int mediaId,
    required int thumbnailId,
  }) async {
    final response = await _apiClient.post(
      '/media-points',
      data: <String, dynamic>{'media_id': mediaId, 'thumbnail_id': thumbnailId},
    );
    return MediaPointDto.fromJson(response);
  }

  Future<void> deleteMediaPoint({required int pointId}) {
    return _apiClient.deleteNoContent('/media-points/$pointId');
  }

  Future<void> deleteMedia({required int mediaId}) {
    return _apiClient.deleteNoContent('/media/$mediaId');
  }

  Future<MediaTransferCandidatesDto> getMediaTransferCandidates({
    required List<int> mediaIds,
  }) async {
    final response = await _apiClient.post(
      '/media-transfers/candidates',
      data: <String, dynamic>{'media_ids': mediaIds},
    );
    return MediaTransferCandidatesDto.fromJson(response);
  }

  Future<MediaTransferAcceptedResponseDto> createMediaTransfer({
    required List<int> mediaIds,
    required int targetLibraryId,
  }) async {
    final response = await _apiClient.post(
      '/media-transfers',
      data: <String, dynamic>{
        'media_ids': mediaIds,
        'target_library_id': targetLibraryId,
      },
    );
    return MediaTransferAcceptedResponseDto.fromJson(response);
  }
}
