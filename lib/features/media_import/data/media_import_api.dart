import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/media_import/data/filesystem_entry_dto.dart';
import 'package:sakuramedia/features/media_import/data/import_accepted_response_dto.dart';
import 'package:sakuramedia/features/media_import/data/media_import_source.dart';

/// 统一媒体导入接口封装。
class MediaImportApi {
  const MediaImportApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<FilesystemListResponseDto> listEntries({String? path}) async {
    final response = await _apiClient.get(
      '/filesystem/entries',
      queryParameters: <String, dynamic>{
        if (path != null && path.isNotEmpty) 'path': path,
      },
    );
    return FilesystemListResponseDto.fromJson(response);
  }

  /// JAV 与普通视频统一进入 `/imports`，进度和结果由 task run 提供。
  Future<ImportAcceptedResponseDto> createImport({
    required String mediaKind,
    required int libraryId,
    required MediaImportSource source,
    TransferMode? transferMode,
    int? collectionId,
  }) async {
    final response = await _apiClient.post(
      '/imports',
      data: <String, dynamic>{
        'media_kind': mediaKind,
        'backend': source.backend,
        'library_id': libraryId,
        ...source.toJson(),
        if (transferMode != null) 'transfer_mode': transferMode.wireValue,
        if (collectionId != null) 'collection_id': collectionId,
      },
    );
    return ImportAcceptedResponseDto.fromJson(response);
  }
}
