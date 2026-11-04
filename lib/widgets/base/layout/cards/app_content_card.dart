import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

class AppContentCard extends StatelessWidget {
  const AppContentCard({
    super.key,
    required this.title,
    required this.child,
    this.padding,
    this.titleStyle,
    this.headerBottomSpacing,
    this.headerLeading,
    this.headerTrailing,
    this.backgroundColor,
    this.borderColor,
  });

  final String? title;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final TextStyle? titleStyle;
  final double? headerBottomSpacing;

  /// 标题前的图标/状态块；只在有 [title] 时渲染。
  final Widget? headerLeading;
  final Widget? headerTrailing;

  /// 卡片底色；默认 `surfaceCard`。
  final Color? backgroundColor;

  /// 卡片描边；默认 `borderSubtle`。
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final titleText = title == null
        ? null
        : Text(
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
    final hasHeaderLeading = headerLeading != null;
    final hasHeaderTrailing = headerTrailing != null;
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(context.appSpacing.lg),
      decoration: BoxDecoration(
        color: backgroundColor ?? context.appColors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(
          color: borderColor ?? context.appColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titleText != null) ...[
            if (!hasHeaderLeading && !hasHeaderTrailing)
              titleText
            else
              Row(
                children: [
                  if (hasHeaderLeading) ...[
                    headerLeading!,
                    SizedBox(width: context.appSpacing.md),
                  ],
                  Expanded(child: titleText),
                  if (hasHeaderTrailing) ...[
                    SizedBox(width: context.appSpacing.md),
                    headerTrailing!,
                  ],
                ],
              ),
            SizedBox(height: headerBottomSpacing ?? context.appSpacing.lg),
          ],
          child,
        ],
      ),
    );
  }
}
