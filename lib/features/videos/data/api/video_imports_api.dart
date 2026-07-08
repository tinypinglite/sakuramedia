import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/videos/data/dto/video_import_job_dto.dart';

/// 视频（PornBox）导入接口（`/video-imports`）。
///
/// 与 JAV 导入同构的异步搬库作业：按 `transfer_mode` 把视频目录/单文件搬入指定媒体库，
/// 登记 `VideoItem` + `Media` 并可一并关联合集。触发返回 202，进度经作业详情或活动流查询。
/// 目录浏览能力复用 `MediaImportApi.listEntries`。
class VideoImportsApi {
  const VideoImportsApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// 触发视频导入（异步）。
  Future<VideoImportTriggerResponseDto> createVideoImport({
    required int libraryId,
    required String sourcePath,
    TransferMode transferMode = TransferMode.auto,
    int? collectionId,
  }) async {
    final response = await _apiClient.post(
      '/video-imports',
      data: <String, dynamic>{
        'library_id': libraryId,
        'source_path': sourcePath.trim(),
        'transfer_mode': transferMode.wireValue,
        if (collectionId != null) 'collection_id': collectionId,
      },
    );
    return VideoImportTriggerResponseDto.fromJson(response);
  }

  /// 分页查询视频导入作业（按 id 倒序）。
  Future<PaginatedResponseDto<VideoImportJobListItemDto>> listVideoImportJobs({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiClient.get(
      '/video-imports',
      queryParameters: <String, dynamic>{'page': page, 'page_size': pageSize},
    );
    return PaginatedResponseDto<VideoImportJobListItemDto>.fromJson(
      response,
      VideoImportJobListItemDto.fromJson,
    );
  }

  /// 查询视频导入作业详情（含 `failed_files`）。
  Future<VideoImportJobDto> getVideoImportJob(int videoImportJobId) async {
    final response = await _apiClient.get('/video-imports/$videoImportJobId');
    return VideoImportJobDto.fromJson(response);
  }

  /// 重导失败文件。[files] 为空表示重导全部可重导（kind=file）失败文件。
  Future<VideoImportTriggerResponseDto> retryFailedFiles(
    int videoImportJobId, {
    List<String>? files,
  }) async {
    final response = await _apiClient.post(
      '/video-imports/$videoImportJobId/retry',
      data: <String, dynamic>{if (files != null) 'files': files},
    );
    return VideoImportTriggerResponseDto.fromJson(response);
  }

  /// 删除失败源文件，返回更新后的作业详情。
  Future<VideoImportJobDto> deleteFailedFile(
    int videoImportJobId, {
    required String path,
  }) async {
    final response = await _apiClient.delete(
      '/video-imports/$videoImportJobId/failed-files',
      data: <String, dynamic>{'path': path},
    );
    return VideoImportJobDto.fromJson(response);
  }

  /// 重命名失败源文件，返回更新后的作业详情。
  Future<VideoImportJobDto> renameFailedFile(
    int videoImportJobId, {
    required String path,
    required String newName,
  }) async {
    final response = await _apiClient.post(
      '/video-imports/$videoImportJobId/failed-files/rename',
      data: <String, dynamic>{'path': path, 'new_name': newName},
    );
    return VideoImportJobDto.fromJson(response);
  }
}
