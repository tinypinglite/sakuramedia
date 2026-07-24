import 'package:sakuramedia/core/json/json_parse.dart';

/// 批量重置里未能重置的单项。
///
/// 后端自「部分成功」语义起返回：合格记录照常重置，不合格记录只出现在这里，
/// 不再整批 4xx。一个 `resource_id` 只回报一个最主要的原因。
class MediaThumbnailResetSkippedItemDto {
  const MediaThumbnailResetSkippedItemDto({
    required this.resourceId,
    required this.reason,
  });

  /// 该 ID 没有 media_thumbnail_generation 任务记录。
  static const String reasonTaskStateNotFound = 'task_state_not_found';

  /// 任务记录存在但媒体已被删除。
  static const String reasonMediaNotFound = 'media_not_found';

  /// 媒体存在但 valid = false。
  static const String reasonMediaInvalid = 'media_invalid';

  /// 媒体正常，但任务记录当前状态不是 failed。
  static const String reasonNotFailed = 'not_failed';

  final int resourceId;
  final String reason;

  /// 展示用中文文案；未知原因回落为原始值，便于后端新增原因时不至于空白。
  String get reasonLabel {
    switch (reason) {
      case reasonTaskStateNotFound:
        return '没有缩略图任务记录';
      case reasonMediaNotFound:
        return '媒体已被删除';
      case reasonMediaInvalid:
        return '媒体已失效';
      case reasonNotFailed:
        return '任务当前不是失败状态';
      default:
        return reason.isEmpty ? '未知原因' : reason;
    }
  }

  factory MediaThumbnailResetSkippedItemDto.fromJson(Map<String, dynamic> json) {
    return MediaThumbnailResetSkippedItemDto(
      resourceId: asInt(json['resource_id']),
      reason: asStringOrNull(json['reason'], trim: true) ?? '',
    );
  }
}

class MediaThumbnailResetResultDto {
  const MediaThumbnailResetResultDto({
    required this.taskKey,
    required this.state,
    required this.resetCount,
    required this.resourceIds,
    this.skippedCount = 0,
    this.skipped = const <MediaThumbnailResetSkippedItemDto>[],
  });

  final String taskKey;
  final String state;

  /// 真正被重置的条数。全部被跳过时为 0，此时响应仍是 200。
  final int resetCount;

  /// 真正被重置的 ID，不含被跳过的。
  final List<int> resourceIds;

  final int skippedCount;
  final List<MediaThumbnailResetSkippedItemDto> skipped;

  bool get hasSkipped => skipped.isNotEmpty || skippedCount > 0;

  Set<int> get skippedResourceIds =>
      skipped.map((item) => item.resourceId).toSet();

  factory MediaThumbnailResetResultDto.fromJson(Map<String, dynamic> json) {
    final rawIds = json['resource_ids'];
    final rawSkipped = json['skipped'];
    final skipped =
        rawSkipped is List
            ? rawSkipped
                .map(asMapOrNull)
                .whereType<Map<String, dynamic>>()
                .map(MediaThumbnailResetSkippedItemDto.fromJson)
                .toList(growable: false)
            : const <MediaThumbnailResetSkippedItemDto>[];
    return MediaThumbnailResetResultDto(
      taskKey: json['task_key'] as String? ?? '',
      state: json['state'] as String? ?? '',
      resetCount: asInt(json['reset_count']),
      resourceIds:
          rawIds is List
              ? rawIds
                  .whereType<num>()
                  .map((value) => value.toInt())
                  .toList(growable: false)
              : const <int>[],
      // 老后端不下发 skipped_count 时按已解析的 skipped 长度兜底。
      skippedCount: asInt(json['skipped_count'], fallback: skipped.length),
      skipped: skipped,
    );
  }
}
