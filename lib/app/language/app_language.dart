import 'package:flutter/widgets.dart';

/// 应用支持的界面语言。后端语言标签固定为 BCP-47 的 zh-CN / en；
/// Flutter 侧使用通用 zh（gen-l10n 要求 zh_CN 提供 zh 基础回退）。
enum AppLanguage {
  zhCN('zh-CN'),
  en('en');

  const AppLanguage(this.apiTag);

  final String apiTag;

  Locale get locale => switch (this) {
    AppLanguage.zhCN => const Locale('zh'),
    AppLanguage.en => const Locale('en'),
  };

  static AppLanguage? tryFromTag(String? tag) {
    if (tag == null) {
      return null;
    }
    final normalized = tag.trim().replaceAll('_', '-').toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized == 'zh' ||
        normalized == 'zh-cn' ||
        normalized == 'zh-sg' ||
        normalized.startsWith('zh-hans')) {
      return AppLanguage.zhCN;
    }
    if (normalized == 'en' || normalized.startsWith('en-')) {
      return AppLanguage.en;
    }
    return null;
  }
}
