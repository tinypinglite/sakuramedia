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
    return Row(
      children: [
        leading,
        const Spacer(),
        Text(
          totalText,
          key: totalKey,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
