/// 「多久以前」的相对时间标签。
///
/// 用于"这件事最近一次发生在什么时候"——系统诊断的上次检测、订阅影片的上次资源
/// 查询等。绝对时间戳走 `updated_at_label.dart` 的 `formatUpdatedAtLabel`，两者
/// 语义不同：相对时间回答"新不新鲜"，绝对时间回答"到底是哪一刻"。
library;

import 'package:sakuramedia/l10n/app_localizations.dart';

/// 把 [moment] 格式化成当前语言的相对时间标签（刚刚 / N 分钟前 / N 小时前 / N 天前）。
///
/// 语境后缀（如「检测」「查过」）由调用方用完整的 ARB key 组合，避免中英文
/// 语序差异导致拼接出病句。
/// [now] 仅供测试注入；不传取当前时间。
///
/// 未来时间（[moment] 晚于 [now]）一律归到「刚刚」——时钟漂移或服务端时区偏差不该
/// 显示成"-3 分钟前"这种明显是 bug 的文案。
String formatRelativeTimeLabel(
  DateTime moment, {
  required AppLocalizations l10n,
  DateTime? now,
}) {
  final diff = (now ?? DateTime.now()).difference(moment);
  if (diff.inMinutes < 1) return l10n.relativeTimeJustNow;
  if (diff.inMinutes < 60) {
    return l10n.relativeTimeMinutesAgo(diff.inMinutes);
  }
  if (diff.inHours < 24) {
    return l10n.relativeTimeHoursAgo(diff.inHours);
  }
  return l10n.relativeTimeDaysAgo(diff.inDays);
}
