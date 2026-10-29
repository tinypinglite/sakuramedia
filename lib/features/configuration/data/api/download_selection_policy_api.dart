import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_selection_policy_dto.dart';

class DownloadSelectionPolicyApi {
  const DownloadSelectionPolicyApi({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<DownloadSelectionPolicyDto> getPolicy() async {
    final response = await _apiClient.get('/download-selection-policy');
    return DownloadSelectionPolicyDto.fromJson(response);
  }

  Future<DownloadSelectionPolicyDto> updatePolicy({
    required int expectedVersion,
    required DownloadSelectionRulesDto rules,
  }) async {
    final response = await _apiClient.put(
      '/download-selection-policy',
      data: DownloadSelectionPolicyUpdatePayload(
        expectedVersion: expectedVersion,
        rules: rules,
      ).toJson(),
    );
    return DownloadSelectionPolicyDto.fromJson(response);
  }

  Future<DownloadSelectionPreviewDto> preview({
    required String movieNumber,
    required DownloadSelectionRulesDto rules,
  }) async {
    final response = await _apiClient.post(
      '/download-selection-policy/preview',
      data: <String, dynamic>{
        'movie_number': movieNumber,
        'rules': rules.toJson(),
      },
      receiveTimeout: const Duration(minutes: 2),
    );
    return DownloadSelectionPreviewDto.fromJson(response);
  }
}
