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
      updatedCount: _toInt(json['updated_count']),
      unreadCount: _toInt(json['unread_count']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}
