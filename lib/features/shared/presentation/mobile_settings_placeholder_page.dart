import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';

class MobileSettingsPlaceholderPage extends StatelessWidget {
  const MobileSettingsPlaceholderPage({
    super.key,
    required this.pageKey,
    this.message = '开发中',
  });

  final Key pageKey;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.surfaceCard,
      child: Center(
        child: AppEmptyState(
          key: pageKey,
          message: message,
        ),
      ),
    );
  }
}
