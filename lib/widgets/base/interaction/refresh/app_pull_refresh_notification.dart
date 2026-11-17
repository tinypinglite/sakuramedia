import 'package:flutter/widgets.dart';

/// 下拉指示器已负责反馈，通知外层结果加载组件避免重复显示。
class AppPullRefreshNotification extends Notification {
  const AppPullRefreshNotification({required this.isRefreshing});
  final bool isRefreshing;
}

Future<void> runAppPullRefresh(
  BuildContext context,
  Future<void> Function() onRefresh,
) async {
  const AppPullRefreshNotification(isRefreshing: true).dispatch(context);
  try {
    await onRefresh();
  } finally {
    if (context.mounted) {
      const AppPullRefreshNotification(isRefreshing: false).dispatch(context);
    }
  }
}
