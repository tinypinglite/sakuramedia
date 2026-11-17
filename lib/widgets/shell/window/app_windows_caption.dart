import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:window_manager/window_manager.dart';

bool get usesAppWindowsCaption =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

/// Reuses the native-style controls and maximize-state listener from window_manager.
///
/// 标题栏背景始终透明；[overlay] 只决定按钮图标是否使用深色底配色。
class AppWindowsCaption extends StatelessWidget {
  const AppWindowsCaption({
    super.key,
    this.standalone = false,
    this.overlay = false,
  });

  final bool standalone;

  /// 顶栏悬浮在封面之上（沉浸式详情页）时置真。
  ///
  /// 此时底衬是半透明暗色渐变，按钮需要使用白色图标；普通页则跟随明暗主题。
  final bool overlay;

  @override
  Widget build(BuildContext context) {
    final height = context.appComponentTokens.desktopTitleBarHeight;
    return SizedBox(
      height: height,
      width: standalone ? null : height * 3,
      child: WindowCaption(
        // 沉浸顶栏的底衬恒为深色渐变（见 AppTopBar），按钮必须走深色配套的
        // 白色图标；普通页跟随明暗主题。背景始终透明，直接露出 ambient 画布
        // 或页面底色，避免右上角出现与周围割裂的实色块。
        brightness: overlay ? Brightness.dark : Theme.of(context).brightness,
        backgroundColor: Colors.transparent,
        title: standalone
            ? Text(
                'SakuraMedia',
                style: resolveAppTextStyle(context, size: AppTextSize.s14),
              )
            : null,
      ),
    );
  }
}
