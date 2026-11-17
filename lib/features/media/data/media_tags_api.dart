import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/media/data/media_tag_dto.dart';

class MediaTagsApi {
  const MediaTagsApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// 拉取全部媒体文件标签；排序沿用后端默认（媒体数倒序）。
  Future<List<MediaTagDto>> getTags() async {
    final response = await _apiClient.getList('/media-tags');
    return response.map(MediaTagDto.fromJson).toList(growable: false);
  }

  Future<MediaTagDto> createTag(MediaTagUpsertPayload payload) async {
    final response = await _apiClient.post(
      '/media-tags',
      data: payload.toJson(),
    );
    return MediaTagDto.fromJson(response);
  }

  Future<MediaTagDto> updateTag({
    required int tagId,
    required MediaTagUpsertPayload payload,
  }) async {
    final response = await _apiClient.put(
      '/media-tags/$tagId',
      data: payload.toJson(),
    );
    return MediaTagDto.fromJson(response);
  }

  Future<void> deleteTag(int tagId) {
    return _apiClient.deleteNoContent('/media-tags/$tagId');
  }

  Future<List<MediaTagPreviewMatchDto>> preview({
    required String fileName,
    String? releaseTitle,
    String? releaseDescription,
  }) async {
    final response = await _apiClient.post(
      '/media-tags/preview',
      data: <String, dynamic>{
        'file_name': fileName.trim(),
        if (_normalized(releaseTitle) != null)
          'release_title': _normalized(releaseTitle),
        if (_normalized(releaseDescription) != null)
          'release_description': _normalized(releaseDescription),
      },
    );
    final matches = response['matches'];
    if (matches is! List) return const <MediaTagPreviewMatchDto>[];
    return matches
        .map(asMapOrNull)
        .whereType<Map<String, dynamic>>()
        .map(MediaTagPreviewMatchDto.fromJson)
        .toList(growable: false);
  }

  Future<MediaTagAssignmentDto> getAssignment(int mediaId) async {
    final response = await _apiClient.get('/media/$mediaId/tags');
    return MediaTagAssignmentDto.fromJson(response);
  }

  Future<MediaTagAssignmentDto> setAssignment({
    required int mediaId,
    required List<int> tagIds,
  }) async {
    final response = await _apiClient.put(
      '/media/$mediaId/tags',
      data: <String, dynamic>{'tag_ids': tagIds},
    );
    return MediaTagAssignmentDto.fromJson(response);
  }

  Future<MediaTagAssignmentDto> resetAssignmentToAuto(int mediaId) async {
    final response = await _apiClient.post('/media/$mediaId/tags/reset');
    return MediaTagAssignmentDto.fromJson(response);
  }
}

String? _normalized(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
