import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/media_import/data/import_accepted_response_dto.dart';
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
}
