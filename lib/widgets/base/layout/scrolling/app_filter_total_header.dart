import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
  }
}
