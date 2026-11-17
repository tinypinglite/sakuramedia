import 'package:flutter/widgets.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';

export 'package:sakuramedia/l10n/app_localizations.dart';

/// 中文兜底实例。复用同一份，避免每次取文案都新建一个。
final AppLocalizations _zhFallback = AppLocalizationsZh();

/// 取当前语言的 ARB 文案。
///
/// 通用组件不假设宿主一定挂了 `AppLocalizations` delegate：挂了，就按当前
/// 语言取；没挂，就退回中文（与迁移前的硬编码文案一致）。这样组件被嵌进
/// 裸 `MaterialApp`、弹层或第三方容器时，不会因为取文案整块崩掉。
///
/// 注意：只能在 `build` 或元素仍处于 active 状态时调用（内部走
/// `dependOnInheritedWidgetOfExactType`）。
AppLocalizations appL10n(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    _zhFallback;
