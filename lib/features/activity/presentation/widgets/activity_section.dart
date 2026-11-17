import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

/// 带标题的内容段：任务中心各区块（活动任务 / 任务历史）共用。
class ActivitySection extends StatelessWidget {
  const ActivitySection({
    super.key,
    required this.title,
    required this.child,
    this.titleStyle,
    this.trailing,
  });

  final String title;
  final Widget child;
  final TextStyle? titleStyle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final titleWidget = Text(
      title,
      style:
          titleStyle ??
          resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (trailing == null)
          titleWidget
        else
          Row(
            children: [
              Expanded(child: titleWidget),
              SizedBox(width: context.appSpacing.md),
              trailing!,
            ],
          ),
        SizedBox(height: context.appSpacing.lg),
        child,
      ],
    );
  }
}
