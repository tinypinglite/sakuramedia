import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/videos/data/video_import_result_dto.dart';

/// 视频就地导入接口（`/video-imports`）。
///
/// 不搬运文件：按 `Media.path` 与内容指纹去重，逐个视频文件建 `VideoItem` + `Media`，
/// 并按入参关联标签/人物/合集。目录浏览能力复用 `MediaImportApi.listEntries`。
class VideoImportsApi {
  const VideoImportsApi({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<VideoImportResultDto> createVideoImport({
    required String sourcePath,
    int? libraryId,
    List<int> tagIds = const <int>[],
    List<int> personIds = const <int>[],
    int? collectionId,
  }) async {
    final response = await _apiClient.post(
      '/video-imports',
      data: <String, dynamic>{
        'source_path': sourcePath.trim(),
        if (libraryId != null) 'library_id': libraryId,
        'tag_ids': tagIds,
        'person_ids': personIds,
        if (collectionId != null) 'collection_id': collectionId,
      },
    );
    return VideoImportResultDto.fromJson(response);
  }
}
