import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

class MovieDetailSection extends StatelessWidget {
  const MovieDetailSection({
    super.key,
    required this.title,
    required this.child,
    this.titleBottomSpacing,
  });

  final String title;
  final Widget child;
  final double? titleBottomSpacing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: context.appComponentTokens.movieDetailSectionGap,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          SizedBox(
            height:
                titleBottomSpacing ??
                context.appComponentTokens.movieDetailSectionTitleGap,
          ),
          child,
        ],
      ),
    );
  }
}
