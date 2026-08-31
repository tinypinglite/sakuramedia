import 'package:flutter/foundation.dart';

/// 一个失败诊断项的「去修复」跳转目标。
///
/// 目前只描述配置页某个 tab（tab index 见 `desktop_configuration_page.dart`：
/// 1=媒体库 / 2=下载器 / 3=索引器）。
///
/// 用值对象而不是直接存 int：方便后续扩展跳到别的页（例如日志页）。
@immutable
class DiagnosticFixTarget {
  const DiagnosticFixTarget.configurationTab(this.configurationTabIndex);

  final int configurationTabIndex;

  @override
  bool operator ==(Object other) {
    return other is DiagnosticFixTarget &&
        other.configurationTabIndex == configurationTabIndex;
  }

  @override
  int get hashCode => configurationTabIndex.hashCode;
}
