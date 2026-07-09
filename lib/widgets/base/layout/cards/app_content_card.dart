import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

class AppContentCard extends StatelessWidget {
  const AppContentCard({
    super.key,
    required this.title,
    required this.child,
    this.padding,
    this.titleStyle,
    this.headerBottomSpacing,
    this.headerTrailing,
  });

  final String title;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final TextStyle? titleStyle;
  final double? headerBottomSpacing;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(context.appSpacing.xl),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: context.appColors.borderSubtle),
        boxShadow: context.appShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (headerTrailing == null)
            Text(
              title,
              style:
                  titleStyle ??
                  resolveAppTextStyle(
                    context,
                    size: AppTextSize.s18,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style:
                        titleStyle ??
                        resolveAppTextStyle(
                          context,
                          size: AppTextSize.s18,
                          weight: AppTextWeight.semibold,
                          tone: AppTextTone.primary,
                        ),
                  ),
                ),
                SizedBox(width: context.appSpacing.md),
                headerTrailing!,
              ],
            ),
          SizedBox(height: headerBottomSpacing ?? context.appSpacing.lg),
          child,
        ],
      ),
    );
  }
}
