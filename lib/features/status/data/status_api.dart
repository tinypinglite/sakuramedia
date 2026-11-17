import 'package:sakuramedia/config/app_release_channels.dart';
import 'package:sakuramedia/features/status/data/server_capabilities.dart';
import 'package:sakuramedia/core/format/release_version.dart';
import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';

class StatusApi {
  const StatusApi({required ApiClient apiClient}) : _apiClient = apiClient;

  static const _releaseCheckTimeout = Duration(seconds: 10);

  final ApiClient _apiClient;

  Future<ServerCapabilities> getCapabilities() async =>
      ServerCapabilities.fromJson(await _apiClient.get('/status/capabilities'));

  Future<StatusDto> getStatus() async {
    final response = await _apiClient.get('/status');
    return StatusDto.fromJson(response);
  }

  Future<StatusImageSearchDto> getImageSearchStatus() async {
    final response = await _apiClient.get('/status/image-search');
    return StatusImageSearchDto.fromJson(response);
  }

  Future<StatusInsightsDto> getInsights() async {
    final response = await _apiClient.get('/status/insights');
    return StatusInsightsDto.fromJson(response);
  }

  Future<StatusWatchTrendDto> getWatchTrend(WatchTrendRange range) async {
    final response = await _apiClient.get(
      '/status/watch-trend',
      queryParameters: <String, dynamic>{'range': range.apiValue},
    );
    return StatusWatchTrendDto.fromJson(response);
  }

  Future<void> resetImageSearch() => _apiClient.post('/image-search/reset');

  Future<String?> checkFrontendUpdate(String currentVersion) =>
      _checkReleaseUpdate(currentVersion, AppReleaseChannels.frontendApiUrl);

  Future<String?> checkBackendUpdate(String currentVersion) =>
      _checkReleaseUpdate(currentVersion, AppReleaseChannels.backendApiUrl);

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
}
