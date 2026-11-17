import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_pull_refresh_notification.dart';
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
      onRefresh: () => runAppPullRefresh(context, onRefresh),
      color: Theme.of(context).colorScheme.primary,
      backgroundColor: context.appColors.surfaceCard,
      notificationPredicate: notificationPredicate,
      child: child,
    );
  }
}
