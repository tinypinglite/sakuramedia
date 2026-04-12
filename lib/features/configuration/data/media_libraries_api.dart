import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/configuration/data/media_library_dto.dart';

class MediaLibrariesApi {
  const MediaLibrariesApi({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<MediaLibraryDto>> getLibraries() async {
    final response = await _apiClient.getList('/media-libraries');
    return response.map(MediaLibraryDto.fromJson).toList(growable: false);
  }

  Future<MediaLibraryDto> createLibrary(
    CreateMediaLibraryPayload payload,
  ) async {
    final response = await _apiClient.post(
      '/media-libraries',
      data: payload.toJson(),
    );
    return MediaLibraryDto.fromJson(response);
  }

  Future<MediaLibraryDto> updateLibrary({
    required int libraryId,
    required UpdateMediaLibraryPayload payload,
  }) async {
    final response = await _apiClient.patch(
      '/media-libraries/$libraryId',
      data: payload.toJson(),
    );
    return MediaLibraryDto.fromJson(response);
  }

  Future<void> deleteLibrary(int libraryId) {
    return _apiClient.deleteNoContent('/media-libraries/$libraryId');
  }
}
