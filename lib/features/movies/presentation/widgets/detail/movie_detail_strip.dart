import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';

/// 影片详情页横向卡片条的滚动容器。
class MovieDetailStripScroller extends StatelessWidget {
  const MovieDetailStripScroller({
    super.key,
    required this.children,
    this.scrollViewKey,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final List<Widget> children;
  final Key? scrollViewKey;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing.sm;
    return SingleChildScrollView(
      key: scrollViewKey,
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: crossAxisAlignment,
        children: List<Widget>.generate(children.length, (index) {
          return Padding(
            padding: EdgeInsets.only(
              right: index == children.length - 1 ? 0 : spacing,
            ),
            child: children[index],
          );
        }),
      ),
    );
  }
}

/// 影片详情页横向卡片条的空态 / 错误反馈。
class MovieDetailStripFeedback extends StatelessWidget {
  const MovieDetailStripFeedback({
    super.key,
    required this.message,
    this.feedbackKey,
    this.actionLabel,
    this.onAction,
    this.retryKey,
  });

  final String message;
  final Key? feedbackKey;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? retryKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: feedbackKey,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.md,
        vertical: context.appSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.appColors.movieDetailEmptyBackground,
        borderRadius: context.appRadius.mdBorder,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(width: context.appSpacing.sm),
            AppTextButton(
              key: retryKey,
              label: actionLabel!,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}
