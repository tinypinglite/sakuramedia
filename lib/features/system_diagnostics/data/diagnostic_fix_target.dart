import 'package:flutter/foundation.dart';

/// 一个失败诊断项的「去修复」跳转目标。
///
/// 目前只描述配置页某个分类，用 [configurationTabKey] 保存分类的稳定 key
/// （与 `configuration_page.dart` 中 `_ConfigurationCategory.itemKey` 一致），
/// 不再存索引：分类列表会随平台条件变化（如「外部播放器」只在支持的平台出现），
/// 索引会漂移，key 不会。
///
/// 用值对象而不是直接存 String：方便后续扩展跳到别的页（例如日志页）。
@immutable
class DiagnosticFixTarget {
  const DiagnosticFixTarget.configurationTabKey(this.configurationTabKey);

  final String configurationTabKey;

  @override
  bool operator ==(Object other) {
    return other is DiagnosticFixTarget &&
        other.configurationTabKey == configurationTabKey;
  }

  @override
  int get hashCode => configurationTabKey.hashCode;
}
