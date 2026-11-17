import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

/// 移动端骨架占位原子块：纯 surfaceMuted 矩形 + 可选圆角。
///
/// 默认 [radius] 为 `null` 时沿用 `smBorder`（旧行为）；调用方可以传
/// `context.appRadius.mdBorder` 用于头像块之类需要更大圆角的场景。
class AppSkeletonBlock extends StatelessWidget {
  const AppSkeletonBlock({super.key, this.width, this.height, this.radius});

  final double? width;
  final double? height;
  final BorderRadius? radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: radius ?? context.appRadius.smBorder,
      ),
    );
  }
}
