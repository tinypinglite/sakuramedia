import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/media_import/data/import_accepted_response_dto.dart';

/// 字幕目录导入接口封装。
class SubtitleImportApi {
  const SubtitleImportApi({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<ImportAcceptedResponseDto> createSubtitleImport({
    required String sourcePath,
  }) async {
    final response = await _apiClient.post(
      '/subtitle-imports',
      data: <String, dynamic>{'source_path': sourcePath.trim()},
    );
    return ImportAcceptedResponseDto.fromJson(response);
  }
}
