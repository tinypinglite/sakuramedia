import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

/// 「左侧筛选/标题 + 右侧总数(+尾随操作)」的列表顶栏。
///
/// **恒定单行、高度与 [AppListHeader] 严格一致**（`top: xs` + `mobileTopTabHeight`）
/// ——同一个页面在常规态 / 多选态之间、不同页面之间切换时都不该出现高度跳变。
/// 尚未迁到 `AppListHeader` 的页面用它，两者视觉高度对齐后可以逐个平滑替换。
///
/// [leading] 必须是**单行**内容（筛选入口 / 区块标题）。整段说明文字请放在
/// 顶栏之外自成一行，别塞进 leading——顶栏不换行。
class AppFilterTotalHeader extends StatelessWidget {
  const AppFilterTotalHeader({
    super.key,
    required this.leading,
    required this.totalText,
    this.totalKey,
    this.trailing,
  });

  final Widget leading;
  final String totalText;
  final Key? totalKey;

  /// 「N 个」总数右侧的尾随内容（同一行），可选。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final componentTokens = context.appComponentTokens;
    final trailingWidget = trailing;

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: leading),
        SizedBox(width: spacing.md),
        SizedBox(
          height: componentTokens.buttonHeightSm,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              totalText,
              key: totalKey,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
          ),
        ),
        if (trailingWidget != null) ...[
          SizedBox(width: spacing.sm),
          trailingWidget,
        ],
      ],
    );

    return Padding(
      padding: EdgeInsets.only(top: spacing.xs),
      child: SizedBox(height: componentTokens.mobileTopTabHeight, child: row),
    );
  }
}
