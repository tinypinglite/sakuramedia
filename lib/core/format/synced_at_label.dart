import 'package:intl/intl.dart';

/// 将批次抓取时间格式化为可读标签，如「更新于 05/08 09:00」。
/// 后端返回的是本地时区时间，无需再做时区换算；无数据时返回 `null`。
String? formatSyncedAtLabel(DateTime? syncedAt) {
  if (syncedAt == null) {
    return null;
  }
  return '更新于 ${DateFormat('MM/dd HH:mm').format(syncedAt)}';
}

/// 把总数文案与抓取时间组合成头部展示文案，如「12 部 · 更新于 05/08 09:00」。
/// 抓取时间为空时仅保留总数文案。
String composeTotalWithSyncedAt(String totalText, DateTime? syncedAt) {
  final label = formatSyncedAtLabel(syncedAt);
  return label == null ? totalText : '$totalText · $label';
}
