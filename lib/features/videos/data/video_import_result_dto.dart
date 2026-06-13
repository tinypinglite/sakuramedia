/// 视频就地导入的结果（`VideoImportResultResource`）。
class VideoImportResultDto {
  const VideoImportResultDto({
    required this.createdCount,
    required this.skippedCount,
    this.videoItemIds = const <int>[],
  });

  final int createdCount;
  final int skippedCount;
  final List<int> videoItemIds;

  factory VideoImportResultDto.fromJson(Map<String, dynamic> json) {
    final rawIds = json['video_item_ids'];
    final ids = rawIds is List
        ? rawIds
            .map(_intFromJson)
            .whereType<int>()
            .toList(growable: false)
        : <int>[];
    return VideoImportResultDto(
      createdCount: _intFromJson(json['created_count']) ?? 0,
      skippedCount: _intFromJson(json['skipped_count']) ?? 0,
      videoItemIds: ids,
    );
  }
}

int? _intFromJson(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
