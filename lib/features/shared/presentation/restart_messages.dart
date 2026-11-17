import 'package:sakuramedia/l10n/app_localizations.dart';

/// 写操作后统一提示「需重启容器才生效」。
///
/// 后端 api / scheduler 以及插件 api / aps 等子进程都由容器承载，用户不需要
/// 区分具体进程，因此所有写操作共用同一句产品文案。
String buildRestartRequiredMessage(String action, AppLocalizations l10n) =>
    l10n.restartRequiredMessage(action);
