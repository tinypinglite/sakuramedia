import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

class AppSectionSkeleton extends StatelessWidget {
  const AppSectionSkeleton({super.key, required this.lineCount});

  final int lineCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List<Widget>.generate(lineCount, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: context.appSpacing.md),
          child: Container(
            width: double.infinity,
            height: 20,
            decoration: BoxDecoration(
              color: context.appColors.surfaceMuted,
              borderRadius: context.appRadius.smBorder,
            ),
          ),
        );
      }),
    );
  }
}
