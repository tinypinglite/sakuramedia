import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/configuration/data/indexer_settings_dto.dart';

class IndexerSettingsApi {
  const IndexerSettingsApi({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<IndexerSettingsDto> getSettings() async {
    final response = await _apiClient.get('/indexer-settings');
    return IndexerSettingsDto.fromJson(response);
  }

  Future<IndexerSettingsDto> updateSettings(
    UpdateIndexerSettingsPayload payload,
  ) async {
    final response = await _apiClient.patch(
      '/indexer-settings',
      data: payload.toJson(),
    );
    return IndexerSettingsDto.fromJson(response);
  }
}
