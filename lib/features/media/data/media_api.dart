import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/media/data/invalid_media_dto.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/data/media_point_dto.dart';
import 'package:sakuramedia/features/media/data/media_point_list_item_dto.dart';
import 'package:sakuramedia/features/media/data/media_rapid_upload_dto.dart';
import 'package:sakuramedia/features/media/data/media_validity_check_result_dto.dart';

class MediaApi {
  const MediaApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// `GET /media`：跨 JAV / videos 域的全局媒体列表。
  ///
  /// - [kind] 传 `all` / `jav` / `video`，`null` 走后端默认（`all`）。
  /// - [libraryId] 指定媒体库过滤，null 时不加参数。
  /// - [actorIds] 订阅女优 OR 筛选，会拼成逗号分隔字符串下发。
  /// - [rapidUploadStatus] 按上次秒传状态过滤：`none / not_hit / failed /
  ///   cleanup_failed / in_progress`，`null` 时不筛选。
  /// - [sort] 例如 `heat:desc`、`file_size_bytes:desc`，`null` 时后端默认 `created_at:desc`。
  Future<PaginatedResponseDto<MediaListItemDto>> getMediaList({
    int page = 1,
    int pageSize = 20,
    String? kind,
    int? libraryId,
    List<int>? actorIds,
    String? rapidUploadStatus,
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
    if (rapidUploadStatus != null && rapidUploadStatus.isNotEmpty) {
      queryParameters['rapid_upload_status'] = rapidUploadStatus;
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

  /// `POST /media/rapid-uploads`：异步创建一次秒传批次。
  Future<MediaRapidUploadTriggerResponseDto> createMediaRapidUpload({
    required List<int> mediaIds,
    required int targetLibraryId,
  }) async {
    final response = await _apiClient.post(
      '/media/rapid-uploads',
      data: <String, dynamic>{
        'media_ids': mediaIds,
        'target_library_id': targetLibraryId,
      },
    );
    return MediaRapidUploadTriggerResponseDto.fromJson(response);
  }

  /// `GET /media/rapid-uploads`：分页查询秒传批次。
  Future<PaginatedResponseDto<MediaRapidUploadBatchListItemDto>>
      getMediaRapidUploads({int page = 1, int pageSize = 20}) async {
    final response = await _apiClient.get(
      '/media/rapid-uploads',
      queryParameters: <String, dynamic>{'page': page, 'page_size': pageSize},
    );
    return PaginatedResponseDto<MediaRapidUploadBatchListItemDto>.fromJson(
      response,
      MediaRapidUploadBatchListItemDto.fromJson,
    );
  }

  /// `GET /media/rapid-uploads/{batch_id}`：单批次含 items 详情。
  Future<MediaRapidUploadBatchDto> getMediaRapidUpload({
    required int batchId,
  }) async {
    final response = await _apiClient.get('/media/rapid-uploads/$batchId');
    return MediaRapidUploadBatchDto.fromJson(response);
  }

  /// `POST /media/rapid-uploads/{batch_id}/retry`：只重试失败/清理失败项。
  ///
  /// 若批次无可重试项，后端会以 `422 media_rapid_upload_no_retryable_items` 拒绝。
  Future<MediaRapidUploadTriggerResponseDto> retryMediaRapidUpload({
    required int batchId,
  }) async {
    final response = await _apiClient.post(
      '/media/rapid-uploads/$batchId/retry',
    );
    return MediaRapidUploadTriggerResponseDto.fromJson(response);
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

  Future<MediaValidityCheckResultDto> checkMediaValidity({
    required int mediaId,
  }) async {
    final response = await _apiClient.post('/media/$mediaId/validity-check');
    return MediaValidityCheckResultDto.fromJson(response);
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
