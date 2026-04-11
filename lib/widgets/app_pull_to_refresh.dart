import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

class AppPullToRefresh extends StatelessWidget {
  const AppPullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.notificationPredicate = defaultScrollNotificationPredicate,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final ScrollNotificationPredicate notificationPredicate;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator.adaptive(
      onRefresh: onRefresh,
      color: Theme.of(context).colorScheme.primary,
      backgroundColor: context.appColors.surfaceCard,
      notificationPredicate: notificationPredicate,
      child: child,
    );
  }
}
