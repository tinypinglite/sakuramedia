import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/media/data/invalid_media_dto.dart';
import 'package:sakuramedia/features/media/data/media_point_dto.dart';
import 'package:sakuramedia/features/media/data/media_point_list_item_dto.dart';
import 'package:sakuramedia/features/media/data/media_validity_check_result_dto.dart';

class MediaApi {
  const MediaApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<PaginatedResponseDto<MediaPointListItemDto>> getGlobalMediaPoints({
    int page = 1,
    int pageSize = 20,
    String sort = 'created_at:desc',
  }) async {
    final response = await _apiClient.get(
      '/media-points',
      queryParameters: <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        'sort': sort,
      },
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
