import 'package:sakuramedia/core/format/app_date_format.dart';

/// 将「更新时间 / 最后修改时间」格式化为「yyyy/MM/dd HH:mm」本地时间标签。
/// 无数据时返回 `null`。
String? formatUpdatedAtLabel(DateTime? updatedAt) {
  if (updatedAt == null) {
    return null;
  }
  return formatAppDateTime(updatedAt);
}
