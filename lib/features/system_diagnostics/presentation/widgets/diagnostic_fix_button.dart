import 'package:flutter/material.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_fix_target.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';

/// 「去修复 →」跳转按钮。
///
/// 目前 [DiagnosticFixTarget] 只描述配置页，label 显示对应的 tab 名以帮助用户在
/// 跳转后立刻找到该 tab（配置页当前不支持通过 URL 预选 tab，属于 MVP 已知妥协）。
class DiagnosticFixButton extends StatelessWidget {
  const DiagnosticFixButton({super.key, required this.target});

  final DiagnosticFixTarget target;

  /// 必须与 `desktop_configuration_page.dart` 的 `_tabs` 顺序逐项对齐——
  /// 那份列表的下标就是 IndexedStack 索引，改动顺序时这里要同步，否则按钮会指错 tab 名。
  static const Map<int, String> _tabLabels = <int, String>{
    0: '账号安全',
    1: '媒体库',
    2: '下载器',
    3: '索引器',
    4: '下载偏好',
    5: '播放列表',
    6: '高级设置',
  };

  @override
  Widget build(BuildContext context) {
    final tabLabel = _tabLabels[target.configurationTabIndex] ?? '设置';
    return AppButton(
      label: '去修复 · $tabLabel',
      variant: AppButtonVariant.secondary,
      size: AppButtonSize.small,
      trailingIcon: const Icon(Icons.arrow_forward),
      onPressed: () => context.goPrimaryRoute(desktopConfigurationPath),
    );
  }
}
