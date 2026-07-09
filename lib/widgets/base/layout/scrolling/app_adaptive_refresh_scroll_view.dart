import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pull_to_refresh.dart';

class AppAdaptiveRefreshScrollView extends StatelessWidget {
  const AppAdaptiveRefreshScrollView({
    super.key,
    required this.onRefresh,
    required this.slivers,
    this.controller,
    this.physics,
    this.cacheExtent,
  });

  final Future<void> Function() onRefresh;
  final List<Widget> slivers;
  final ScrollController? controller;
  final ScrollPhysics? physics;

  /// 透传给内部 [CustomScrollView]。通知中心传 `0` 收敛视口外预构建，
  /// 避免「无感自动已读」把未展示的卡片提前标记已读。
  final double? cacheExtent;

  @override
  Widget build(BuildContext context) {
    final isIosRefresh = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final scrollView = CustomScrollView(
      key: key,
      controller: controller,
      cacheExtent: cacheExtent,
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      slivers:
          isIosRefresh
              ? <Widget>[
                CupertinoSliverRefreshControl(onRefresh: onRefresh),
                ...slivers,
              ]
              : slivers,
    );

    if (isIosRefresh) {
      return scrollView;
    }

    return AppPullToRefresh(onRefresh: onRefresh, child: scrollView);
  }
}
