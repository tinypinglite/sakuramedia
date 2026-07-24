import 'package:intl/intl.dart';

/// 将批次抓取时间格式化为可读标签，如「更新于 05/08 09:00」。
/// 后端返回的是本地时区时间，无需再做时区换算；无数据时返回 `null`。
///
/// [withPrefix] 传 `false` 时省掉「更新于」三个字，只留「05/08 09:00」——
/// 移动端顶栏横向空间紧张，前缀会把时间挤到省略号里；那里的上下文已经足够
/// 让人看懂这个时间是什么。
String? formatSyncedAtLabel(DateTime? syncedAt, {bool withPrefix = true}) {
  if (syncedAt == null) {
    return null;
  }
  final formatted = DateFormat('MM/dd HH:mm').format(syncedAt);
  return withPrefix ? '更新于 $formatted' : formatted;
}

/// 把总数文案与抓取时间组合成头部展示文案，如「12 部 · 更新于 05/08 09:00」。
/// 抓取时间为空时仅保留总数文案。
String composeTotalWithSyncedAt(String totalText, DateTime? syncedAt) {
  final label = formatSyncedAtLabel(syncedAt);
  return label == null ? totalText : '$totalText · $label';
}
