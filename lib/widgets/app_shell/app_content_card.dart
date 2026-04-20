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
  });

  final String title;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final TextStyle? titleStyle;
  final double? headerBottomSpacing;

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
          ),
          SizedBox(height: headerBottomSpacing ?? context.appSpacing.lg),
          child,
        ],
      ),
    );
  }
}
