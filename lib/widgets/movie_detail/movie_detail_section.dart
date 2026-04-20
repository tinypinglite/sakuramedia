import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

class MovieDetailSection extends StatelessWidget {
  const MovieDetailSection({
    super.key,
    required this.title,
    required this.child,
    this.titleKey,
  });

  final String title;
  final Widget child;
  final Key? titleKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: context.appComponentTokens.movieDetailSectionGap,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            key: titleKey,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.regular,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(
            height: context.appComponentTokens.movieDetailSectionTitleGap,
          ),
          child,
        ],
      ),
    );
  }
}
