import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_sse_event.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/core/network/sse_event_stream_client.dart';
import 'package:sakuramedia/features/downloads/data/download_candidate_dto.dart';
import 'package:sakuramedia/features/downloads/data/download_request_dto.dart';
import 'package:sakuramedia/features/downloads/data/download_task_stream_event_dto.dart';

class DownloadsApi {
  const DownloadsApi({
    required ApiClient apiClient,
    required SseEventStreamClient streamClient,
  }) : _apiClient = apiClient,
       _streamClient = streamClient;

  final ApiClient _apiClient;
  final SseEventStreamClient _streamClient;

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

  Future<PaginatedResponseDto<DownloadTaskDto>> getDownloadTasks({
    int page = 1,
    int pageSize = 20,
    int? clientId,
    String? movieNumber,
    String? downloadState,
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
        if (downloadState != null && downloadState.trim().isNotEmpty)
          'download_state': downloadState,
        if (sort != null && sort.trim().isNotEmpty) 'sort': sort,
      },
    );
    return PaginatedResponseDto<DownloadTaskDto>.fromJson(
      response,
      DownloadTaskDto.fromJson,
    );
  }

  Future<DownloadTaskActionResultDto> pauseDownloadTask(int taskId) async {
    final response = await _apiClient.post('/download-tasks/$taskId/pause');
    return DownloadTaskActionResultDto.fromJson(response);
  }

  Future<DownloadTaskActionResultDto> resumeDownloadTask(int taskId) async {
    final response = await _apiClient.post('/download-tasks/$taskId/resume');
    return DownloadTaskActionResultDto.fromJson(response);
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

  Stream<DownloadTaskStreamEvent> streamDownloadTasks({
    int? clientId,
    String? movieNumber,
  }) {
    final queryParameters = <String, dynamic>{
      if (clientId != null) 'client_id': clientId,
      if (movieNumber != null && movieNumber.trim().isNotEmpty)
        'movie_number': movieNumber,
    };
    return _streamClient
        .connect(
          '/download-tasks/stream',
          queryParameters: queryParameters.isEmpty ? null : queryParameters,
        )
        .map(_mapStreamEvent);
  }

  DownloadTaskStreamEvent _mapStreamEvent(ApiSseEvent event) {
    final payload = event.jsonData;
    return switch (event.event) {
      'heartbeat' => DownloadTaskStreamEvent.heartbeat(),
      'snapshot' => DownloadTaskStreamEvent.snapshot(
        clientId: asInt(payload['client_id']),
        items: _parseSnapshotItems(payload['items']),
      ),
      'download_task_updated' => DownloadTaskStreamEvent.taskUpdated(
        DownloadTaskProgressDto.fromJson(payload),
      ),
      'download_task_removed' => DownloadTaskStreamEvent.taskRemoved(
        DownloadTaskRemovedDto.fromJson(payload),
      ),
      // `download_client_status` 双形态同一事件名：健康帧带 `status`，
      // 传输帧不带。按键存在与否分流，别混显。
      'download_client_status' =>
        payload.containsKey('status')
            ? DownloadTaskStreamEvent.clientHealth(
              DownloadClientHealthDto.fromJson(payload),
            )
            : DownloadTaskStreamEvent.clientTransfer(
              DownloadClientTransferDto.fromJson(payload),
            ),
      _ => DownloadTaskStreamEvent.unknown(),
    };
  }

  List<DownloadTaskProgressDto> _parseSnapshotItems(dynamic value) {
    if (value is! List) {
      return const <DownloadTaskProgressDto>[];
    }
    final result = <DownloadTaskProgressDto>[];
    for (final item in value) {
      if (item is Map) {
        result.add(
          DownloadTaskProgressDto.fromJson(
            item.map(
              (dynamic key, dynamic data) => MapEntry(key.toString(), data),
            ),
          ),
        );
      }
    }
    return result;
  }
}
