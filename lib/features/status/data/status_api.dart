import 'package:sakuramedia/core/format/release_version.dart';
import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';

class StatusApi {
  const StatusApi({required ApiClient apiClient}) : _apiClient = apiClient;

  static const _frontendReleaseApiUrl =
      'https://api.github.com/repos/tinypinglite/sakuramedia/releases/latest';
  static const _backendReleaseApiUrl =
      'https://api.github.com/repos/tinypinglite/sakuramediabe/releases/latest';
  static const _releaseCheckTimeout = Duration(seconds: 10);

  final ApiClient _apiClient;

  Future<StatusDto> getStatus() async {
    final response = await _apiClient.get('/status');
    return StatusDto.fromJson(response);
  }

  Future<StatusImageSearchDto> getImageSearchStatus() async {
    final response = await _apiClient.get('/status/image-search');
    return StatusImageSearchDto.fromJson(response);
  }

  Future<void> resetImageSearch() => _apiClient.post('/image-search/reset');

  Future<String?> checkFrontendUpdate(String currentVersion) =>
      _checkReleaseUpdate(currentVersion, _frontendReleaseApiUrl);

  Future<String?> checkBackendUpdate(String currentVersion) =>
      _checkReleaseUpdate(currentVersion, _backendReleaseApiUrl);

  Future<String?> _checkReleaseUpdate(
    String currentVersion,
    String releaseApiUrl,
  ) async {
    final installedVersion = ReleaseVersion.tryParse(currentVersion);
    if (installedVersion == null) {
      return null;
    }
    final release = await _apiClient.get(
      releaseApiUrl,
      requiresAuth: false,
      connectTimeout: _releaseCheckTimeout,
      receiveTimeout: _releaseCheckTimeout,
    );
    final latestTag = asStringOrNull(release['tag_name'], trim: true);
    final latestVersion = ReleaseVersion.tryParse(latestTag ?? '');
    if (latestVersion == null) {
      return null;
    }
    if (latestVersion.compareTo(installedVersion) <= 0) {
      return null;
    }
    return latestTag;
  }

  Future<StatusMetadataProviderTestDto> testMetadataProvider(
    String provider,
  ) async {
    final response = await _apiClient.get(
      '/status/metadata-providers/$provider/test',
    );
    return StatusMetadataProviderTestDto.fromJson(response);
  }
}
