import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/navigation/app_tab_bar.dart';

class MobileOverviewSkeletonPage extends StatelessWidget {
  const MobileOverviewSkeletonPage({super.key});

  static const List<String> _tabs = ['我的', '关注', '发现', '时刻'];

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

    return DefaultTabController(
      length: 4,
      child: ColoredBox(
        key: const Key('mobile-overview-skeleton-page'),
        color: colors.surfacePage,
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.only(top: spacing.sm),
                child: const AppTabBar(
                  key: Key('mobile-overview-tabs'),
                  variant: AppTabBarVariant.mobileTop,
                  tabs: [
                    Tab(text: '我的'),
                    Tab(text: '关注'),
                    Tab(text: '发现'),
                    Tab(text: '时刻'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  key: const Key('mobile-overview-tab-view'),
                  children: _tabs
                      .map(
                        (tabLabel) =>
                            _MobileOverviewTabPane(tabLabel: tabLabel),
                      )
                      .toList(growable: false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileOverviewTabPane extends StatelessWidget {
  const _MobileOverviewTabPane({required this.tabLabel});

  final String tabLabel;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    return SingleChildScrollView(
      padding: EdgeInsets.all(spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SkeletonBlock(height: 48),
          SizedBox(height: spacing.lg),
          _SkeletonBlock(height: 180),
          SizedBox(height: spacing.lg),
          _SkeletonBlock(height: 120),
          SizedBox(height: spacing.xl),
          AppEmptyState(message: '$tabLabel内容骨架搭建中'),
        ],
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final radius = context.appRadius;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: radius.mdBorder,
      ),
    );
  }
}
