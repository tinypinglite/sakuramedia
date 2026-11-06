import 'package:json_annotation/json_annotation.dart';
import 'package:sakuramedia/core/json/dto_json_codec.dart';

part 'notification_read_result_dto.g.dart';

/// 批量设置已读状态接口的返回体。
///
/// 后端 `PATCH /system/notifications`（`ids` 或 `all` 指定目标）
/// 返回 `{ updated_count, unread_count }`，前端直接拿 [unreadCount] 刷新角标。
@JsonSerializable(converters: dtoJsonConverters, createToJson: false)
class NotificationReadResultDto {
  const NotificationReadResultDto({
    required this.updatedCount,
    required this.unreadCount,
  });

  final int updatedCount;
  final int unreadCount;

  factory NotificationReadResultDto.fromJson(Map<String, dynamic> json) =>
      _$NotificationReadResultDtoFromJson(json);
}
