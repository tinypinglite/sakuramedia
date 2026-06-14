import 'package:sakuramedia/core/json/json_parse.dart';

/// 批量已读 / 全部已读接口的统一返回体。
///
/// 后端 `POST /system/notifications/read` 与 `POST /system/notifications/read-all`
/// 均返回 `{ updated_count, unread_count }`，前端直接拿 [unreadCount] 刷新角标。
class NotificationReadResultDto {
  const NotificationReadResultDto({
    required this.updatedCount,
    required this.unreadCount,
  });

  final int updatedCount;
  final int unreadCount;

  factory NotificationReadResultDto.fromJson(Map<String, dynamic> json) {
    return NotificationReadResultDto(
      updatedCount: asInt(json['updated_count']),
      unreadCount: asInt(json['unread_count']),
    );
  }
}
