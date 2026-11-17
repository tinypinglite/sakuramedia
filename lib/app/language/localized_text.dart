import 'package:sakuramedia/app/language/app_language.dart';

/// 按「当前语言 → zh-CN → 原文」的顺序解析静态文案。
///
/// 与后端 `src/i18n/text.py` 的 `resolve_text` 保持同样的回退顺序：先取当前
/// 语言，缺失时取 `zh-CN`，再缺失时返回原文 `fallback`。空字符串视作缺失，
/// 与后端 `or` 的真值语义一致。
///
/// 用于服务端不参与解析的静态数据（例如插件市场索引由客户端直连拉取），这类
/// 数据在客户端渲染时按当前语言挑值。
String resolveLocalizedText({
  required Map<String, String> translations,
  required String fallback,
  required AppLanguage language,
}) {
  if (translations.isEmpty) {
    return fallback;
  }
  final current = translations[language.apiTag];
  if (current != null && current.trim().isNotEmpty) {
    return current;
  }
  final chinese = translations['zh-CN'];
  if (chinese != null && chinese.trim().isNotEmpty) {
    return chinese;
  }
  return fallback;
}
