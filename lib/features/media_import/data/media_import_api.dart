import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/media_import/data/import_accepted_response_dto.dart';
import 'package:sakuramedia/features/media_import/data/import_failed_item_dto.dart';
import 'package:sakuramedia/features/media_import/data/import_metadata_search_dto.dart';
import 'package:sakuramedia/features/media_import/data/import_source_dto.dart';
import 'package:sakuramedia/features/media_import/data/media_import_source.dart';

/// 统一媒体导入接口封装。
class MediaImportApi {
  const MediaImportApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<ImportBrowseResponseDto> browseSources({
    required int libraryId,
    Map<String, dynamic>? parentRef,
    String? cursor,
    int limit = 50,
  }) async {
    final response = await _apiClient.post(
      '/import-sources/browse',
      data: <String, dynamic>{
        'library_id': libraryId,
        if (parentRef != null) 'parent_ref': parentRef,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'limit': limit,
      },
    );
    return ImportBrowseResponseDto.fromJson(response);
  }

  /// JAV 与普通视频统一进入 `/imports`，进度和结果由 task run 提供。
  Future<ImportAcceptedResponseDto> createImport({
    required String mediaKind,
    required int libraryId,
    required MediaImportSource source,
    SourceDisposition sourceDisposition = SourceDisposition.keep,
    int? collectionId,
  }) async {
    final response = await _apiClient.post(
      '/imports',
      data: <String, dynamic>{
        'media_kind': mediaKind,
        'library_id': libraryId,
        ...source.toJson(),
        'source_disposition': sourceDisposition.wireValue,
        if (collectionId != null) 'collection_id': collectionId,
      },
    );
    return ImportAcceptedResponseDto.fromJson(response);
  }

  /// 列出某个导入任务运行记录的失败文件（不含宿主内部 source_ref 等字段）。
  Future<List<ImportFailedItemDto>> getFailedItems({
    required int taskRunId,
  }) async {
    final response = await _apiClient.getList(
      '/imports/$taskRunId/failed-items',
    );
    return response.map(ImportFailedItemDto.fromJson).toList(growable: false);
  }

  /// 按用户输入的番号搜索已启用元数据插件的候选。
  Future<ImportMetadataSearchResponseDto> searchMetadataCandidates({
    required int taskRunId,
    required String itemId,
    required String movieNumber,
  }) async {
    final response = await _apiClient.get(
      '/imports/$taskRunId/failed-items/$itemId/metadata-candidates',
      queryParameters: <String, dynamic>{'movie_number': movieNumber},
    );
    return ImportMetadataSearchResponseDto.fromJson(response);
  }

  /// 用选定的元数据候选重试导入失败文件。
  Future<ImportAcceptedResponseDto> retryFailedItem({
    required int taskRunId,
    required String itemId,
    required String candidateId,
  }) async {
    final response = await _apiClient.post(
      '/imports/$taskRunId/failed-items/$itemId/retry',
      data: <String, dynamic>{'candidate_id': candidateId},
    );
    return ImportAcceptedResponseDto.fromJson(response);
  }
}
