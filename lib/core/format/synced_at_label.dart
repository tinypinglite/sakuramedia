import 'package:sakuramedia/core/format/app_date_format.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

/// 将批次抓取时间格式化为可读标签，如「更新于 05/08 09:00」。
/// 后端返回的是本地时区时间，无需再做时区换算；无数据时返回 `null`。
///
/// [withPrefix] 传 `false` 时省掉「更新于」前缀，只留「05/08 09:00」——
/// 移动端顶栏横向空间紧张，前缀会把时间挤到省略号里；那里的上下文已经足够
/// 让人看懂这个时间是什么。
String? formatSyncedAtLabel(
  DateTime? syncedAt, {
  required AppLocalizations l10n,
  bool withPrefix = true,
}) {
  if (syncedAt == null) {
    return null;
  }
  final formatted = formatAppDateTimeCompact(syncedAt);
  return withPrefix ? l10n.syncedAtLabel(formatted) : formatted;
}
