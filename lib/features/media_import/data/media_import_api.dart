import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/media_import/data/filesystem_entry_dto.dart';
import 'package:sakuramedia/features/media_import/data/import_job_dto.dart';

/// 媒体导入接口封装（后端 `media-import` 标签，挂载于根路径）。
class MediaImportApi {
  const MediaImportApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// 浏览后端文件系统目录。
  ///
  /// [path] 为空时：单白名单根直接列内容，多根返回各根概览（响应 `path` 为空串）。
  Future<FilesystemListResponseDto> listEntries({String? path}) async {
    final response = await _apiClient.get(
      '/filesystem/entries',
      queryParameters: <String, dynamic>{
        if (path != null && path.isNotEmpty) 'path': path,
      },
    );
    return FilesystemListResponseDto.fromJson(response);
  }

  /// 触发目录导入。
  Future<ImportJobTriggerResponseDto> createImportJob({
    required int libraryId,
    required String sourcePath,
    TransferMode transferMode = TransferMode.auto,
  }) async {
    final response = await _apiClient.post(
      '/import-jobs',
      data: <String, dynamic>{
        'library_id': libraryId,
        'source_path': sourcePath,
        'transfer_mode': transferMode.wireValue,
      },
    );
    return ImportJobTriggerResponseDto.fromJson(response);
  }

  /// 分页查询导入作业（按 id 倒序）。
  Future<PaginatedResponseDto<ImportJobListItemDto>> listImportJobs({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiClient.get(
      '/import-jobs',
      queryParameters: <String, dynamic>{'page': page, 'page_size': pageSize},
    );
    return PaginatedResponseDto<ImportJobListItemDto>.fromJson(
      response,
      ImportJobListItemDto.fromJson,
    );
  }

  /// 查询导入作业详情（含 `failed_files`）。
  Future<ImportJobDto> getImportJob(int importJobId) async {
    final response = await _apiClient.get('/import-jobs/$importJobId');
    return ImportJobDto.fromJson(response);
  }

  /// 重导失败文件。[files] 为空表示重导全部可重导（kind=file）失败文件。
  Future<ImportJobTriggerResponseDto> retryFailedFiles(
    int importJobId, {
    List<String>? files,
  }) async {
    final response = await _apiClient.post(
      '/import-jobs/$importJobId/retry',
      data: <String, dynamic>{if (files != null) 'files': files},
    );
    return ImportJobTriggerResponseDto.fromJson(response);
  }

  /// 删除失败源文件，返回更新后的作业详情。
  Future<ImportJobDto> deleteFailedFile(
    int importJobId, {
    required String path,
  }) async {
    final response = await _apiClient.delete(
      '/import-jobs/$importJobId/failed-files',
      data: <String, dynamic>{'path': path},
    );
    return ImportJobDto.fromJson(response);
  }

  /// 重命名失败源文件，返回更新后的作业详情。
  Future<ImportJobDto> renameFailedFile(
    int importJobId, {
    required String path,
    required String newName,
  }) async {
    final response = await _apiClient.post(
      '/import-jobs/$importJobId/failed-files/rename',
      data: <String, dynamic>{'path': path, 'new_name': newName},
    );
    return ImportJobDto.fromJson(response);
  }
}
