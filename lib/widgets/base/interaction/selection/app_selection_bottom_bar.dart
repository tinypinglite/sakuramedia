import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_surface.dart';

/// 移动端多选态的**底部**批量操作条：贴底常驻，动作按钮等宽平分整行。
///
/// 与顶部的移动多选头分工明确——顶栏只放「退出 / 计数 / 全选」这类
/// 轻量上下文，真正的批量动作放在这里：拇指够得到、按钮命中区大、危险动作不会
/// 和退出按钮挤在同一处误触。PornBox 视频列表是最早的样板，这里收口成共享件。
///
/// [actions] 通常是 `AppButton`（默认 medium 尺寸即可撑满），按传入顺序等宽排列。
class AppSelectionBottomBar extends StatelessWidget {
  const AppSelectionBottomBar({super.key, required this.actions, this.leading});

  /// 等宽平分的批量动作按钮。
  final List<Widget> actions;

  /// 可选：动作按钮左侧的固定宽度节点（如已选计数），不参与等宽平分。
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final leadingWidget = leading;

    return AppGlassSurface(
      tone: AppGlassTone.chrome,
      borderRadius: BorderRadius.vertical(
        top: context.appRadius.lgBorder.topLeft,
      ),
      padding: EdgeInsets.all(spacing.md),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (leadingWidget != null) ...[
              leadingWidget,
              SizedBox(width: spacing.md),
            ],
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) SizedBox(width: spacing.md),
              Expanded(child: actions[i]),
            ],
          ],
        ),
      ),
    );
  }
}
