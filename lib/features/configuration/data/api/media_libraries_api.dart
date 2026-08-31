import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/configuration/data/dto/cloud115_directory_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/cloud115_qr_login_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';

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

  Future<Cloud115QrTokenDto> getCloud115QrToken() async {
    final response = await _apiClient.post(
      '/media-libraries/cloud115/qrlogin/token',
    );
    return Cloud115QrTokenDto.fromJson(response);
  }

  Future<Cloud115QrStatusDto> pollCloud115QrStatus(
    Cloud115QrTokenDto token,
  ) async {
    final response = await _apiClient.post(
      '/media-libraries/cloud115/qrlogin/status',
      data: token.toStatusRequestJson(),
      receiveTimeout: const Duration(seconds: 45),
    );
    return Cloud115QrStatusDto.fromJson(response);
  }

  Future<MediaLibraryDto> createCloud115Library(
    Cloud115LibraryCreatePayload payload,
  ) async {
    final response = await _apiClient.post(
      '/media-libraries/cloud115',
      data: payload.toJson(),
      receiveTimeout: const Duration(seconds: 60),
    );
    return MediaLibraryDto.fromJson(response);
  }

  Future<MediaLibraryDto> reauthCloud115Library({
    required int libraryId,
    required Cloud115LibraryReauthPayload payload,
  }) async {
    final response = await _apiClient.post(
      '/media-libraries/cloud115/$libraryId/reauth',
      data: payload.toJson(),
      receiveTimeout: const Duration(seconds: 60),
    );
    return MediaLibraryDto.fromJson(response);
  }

  Future<Cloud115DirectoryPageDto> listCloud115Directory({
    required int libraryId,
    String cid = '0',
    int offset = 0,
    int limit = 200,
  }) async {
    final response = await _apiClient.get(
      '/media-libraries/cloud115/$libraryId/entries',
      queryParameters: <String, dynamic>{
        'cid': cid,
        'offset': offset,
        'limit': limit,
      },
    );
    return Cloud115DirectoryPageDto.fromJson(response);
  }
}
