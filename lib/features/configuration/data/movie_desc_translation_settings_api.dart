import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/configuration/data/movie_desc_translation_settings_dto.dart';

class MovieDescTranslationSettingsApi {
  const MovieDescTranslationSettingsApi({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<MovieDescTranslationSettingsDto> getSettings() async {
    final response = await _apiClient.get('/movie-desc-translation-settings');
    return MovieDescTranslationSettingsDto.fromJson(response);
  }

  Future<MovieDescTranslationSettingsDto> updateSettings(
    UpdateMovieDescTranslationSettingsPayload payload,
  ) async {
    final response = await _apiClient.patch(
      '/movie-desc-translation-settings',
      data: payload.toJson(),
    );
    return MovieDescTranslationSettingsDto.fromJson(response);
  }

  Future<bool> testSettings(
    TestMovieDescTranslationSettingsPayload payload,
  ) async {
    final response = await _apiClient.post(
      '/movie-desc-translation-settings/test',
      data: payload.toJson(),
    );
    return response['ok'] == true;
  }
}
