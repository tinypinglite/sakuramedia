import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

class AppFilterTotalHeader extends StatelessWidget {
  const AppFilterTotalHeader({
    super.key,
    required this.leading,
    required this.totalText,
    this.totalKey,
  });

  final Widget leading;
  final String totalText;
  final Key? totalKey;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final componentTokens = context.appComponentTokens;

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
      ],
    );
  }
}
