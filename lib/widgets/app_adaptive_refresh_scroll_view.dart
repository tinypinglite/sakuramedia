import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sakuramedia/widgets/app_pull_to_refresh.dart';

class AppAdaptiveRefreshScrollView extends StatelessWidget {
  const AppAdaptiveRefreshScrollView({
    super.key,
    required this.onRefresh,
    required this.slivers,
    this.controller,
    this.physics,
  });

  final Future<void> Function() onRefresh;
  final List<Widget> slivers;
  final ScrollController? controller;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final isIosRefresh = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final scrollView = CustomScrollView(
      key: key,
      controller: controller,
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
