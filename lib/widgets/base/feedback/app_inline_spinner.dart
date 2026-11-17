import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

/// 行内小转圈：`movieCardLoaderSize` 见方 + `movieCardLoaderStrokeWidth` 线宽。
///
/// 用在「某个小控件正在忙」的位置——卡片上的订阅心形、列表行的动作按钮、加载更多
/// 的页脚。演员详情（桌面 / 移动）与播放列表详情此前各写了一份逐字相同的
/// `SizedBox + CircularProgressIndicator`，统一收口到这里。
///
/// **不是**整页 / 整区块的加载态：那些走 `AppSkeletonizer` 渲染的骨架屏，
/// 转圈只用于局部、短时的忙碌指示。
class AppInlineSpinner extends StatelessWidget {
  const AppInlineSpinner({super.key, this.color});

  /// 不传走平台默认颜色。订阅心形等有专属语义色的位置才传。
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final componentTokens = context.appComponentTokens;
    return SizedBox(
      width: componentTokens.movieCardLoaderSize,
      height: componentTokens.movieCardLoaderSize,
      child: CircularProgressIndicator.adaptive(
        backgroundColor: switch (Theme.of(context).platform) {
          TargetPlatform.iOS || TargetPlatform.macOS => color,
          _ => null,
        },
        strokeWidth: componentTokens.movieCardLoaderStrokeWidth,
        valueColor: AlwaysStoppedAnimation<Color?>(color),
      ),
    );
  }
}
