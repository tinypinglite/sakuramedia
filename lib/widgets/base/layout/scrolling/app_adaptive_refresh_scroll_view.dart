import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_pull_refresh_notification.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_bottom_safe_area_sliver.dart';
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
    final isIosRefresh = defaultTargetPlatform == TargetPlatform.iOS;
    // 底部安全区在这里补：外层移动子页外壳不吞底部安全区，滚动内容铺到屏幕
    // 物理底边，尾部留出等高留白，最后一块内容不会被 home indicator 压住。
    // 根 Tab 壳的玻璃底栏开启 extendBody 后，这里还会包含 Dock 高度，让内容
    // 能穿过底栏并在滚到底时停在 Dock 上方；桌面和抽屉里读到的是 0。
    final paddedSlivers = <Widget>[
      ...slivers,
      ...bottomSafeAreaSliver(context),
    ];
    final scrollView = CustomScrollView(
      key: key,
      controller: controller,
      cacheExtent: cacheExtent,
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      slivers: isIosRefresh
          ? <Widget>[
              CupertinoSliverRefreshControl(
                onRefresh: () => runAppPullRefresh(context, onRefresh),
              ),
              ...paddedSlivers,
            ]
          : paddedSlivers,
    );

    if (isIosRefresh) {
      return scrollView;
    }

    return AppPullToRefresh(onRefresh: onRefresh, child: scrollView);
  }
}
