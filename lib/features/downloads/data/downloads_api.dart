import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
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
      receiveTimeout: const Duration(minutes: 2),
    );
    return DownloadRequestResponseDto.fromJson(response);
  }

  Future<PaginatedResponseDto<DownloadTaskDto>> getDownloadTasks({
    int page = 1,
    int pageSize = 20,
    int? clientId,
    String? movieNumber,
    List<String>? states,
    String? sort,
  }) async {
    final response = await _apiClient.get(
      '/download-tasks',
      queryParameters: <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        if (clientId != null) 'client_id': clientId,
        if (movieNumber != null && movieNumber.trim().isNotEmpty)
          'movie_number': movieNumber,
        if (states != null && states.isNotEmpty) 'state': states,
        if (sort != null && sort.trim().isNotEmpty) 'sort': sort,
      },
    );
    return PaginatedResponseDto<DownloadTaskDto>.fromJson(
      response,
      DownloadTaskDto.fromJson,
    );
  }

  /// 删除下载任务；`deleteFiles=true` 时把双确认 `confirm_delete_files`
  /// 一起塞进 query，避免调用点漏传 422。
  Future<void> deleteDownloadTask(
    int taskId, {
    bool deleteFiles = false,
  }) async {
    await _apiClient.deleteNoContent(
      '/download-tasks/$taskId',
      queryParameters: <String, dynamic>{
        'delete_files': deleteFiles,
        if (deleteFiles) 'confirm_delete_files': true,
      },
    );
  }
}
