import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/downloads/data/download_candidate_dto.dart';
import 'package:sakuramedia/features/downloads/data/download_request_dto.dart';

class DownloadsApi {
  const DownloadsApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<DownloadCandidateDto>> searchCandidates({
    required String movieNumber,
    String? indexerKind,
  }) async {
    final queryParameters = <String, dynamic>{'movie_number': movieNumber};
    if (indexerKind != null && indexerKind.trim().isNotEmpty) {
      queryParameters['indexer_kind'] = indexerKind.trim();
    }

    final response = await _apiClient.getList(
      '/download-candidates',
      queryParameters: queryParameters,
    );
    return response.map(DownloadCandidateDto.fromJson).toList(growable: false);
  }

  Future<DownloadRequestResponseDto> createDownloadRequest({
    required String movieNumber,
    required int clientId,
    required DownloadCandidateDto candidate,
  }) async {
    final response = await _apiClient.post(
      '/download-requests',
      data: <String, dynamic>{
        'client_id': clientId,
        'movie_number': movieNumber,
        'candidate': candidate.toCreatePayloadJson(),
      },
    );
    return DownloadRequestResponseDto.fromJson(response);
  }
}
