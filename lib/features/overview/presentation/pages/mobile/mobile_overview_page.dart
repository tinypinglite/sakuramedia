import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/clips/presentation/pages/mobile/overview_clips_tab.dart';
import 'package:sakuramedia/features/discovery/presentation/mobile_overview_discover_tab.dart';
import 'package:sakuramedia/features/moments/presentation/pages/mobile/overview_moments_tab.dart';
import 'package:sakuramedia/features/overview/presentation/pages/mobile/mobile_overview_my_tab.dart';
import 'package:sakuramedia/features/overview/presentation/providers/mobile_overview_tab_index_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/layout/keep_alive_page.dart';
import 'package:sakuramedia/widgets/base/navigation/app_tab_bar.dart';

class MobileOverviewPage extends ConsumerStatefulWidget {
  const MobileOverviewPage({super.key});

  @override
  ConsumerState<MobileOverviewPage> createState() => _MobileOverviewPageState();
}

class _MobileOverviewPageState extends ConsumerState<MobileOverviewPage>
    with SingleTickerProviderStateMixin {
  static const int _tabCount = 4;

  late final TabController _tabController;
  late final MobileOverviewTabIndex _tabIndex;

  @override
  void initState() {
    super.initState();
    _tabIndex = ref.read(mobileOverviewTabIndexProvider.notifier);
    _tabController = TabController(length: _tabCount, vsync: this)
      ..addListener(_reportTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _reportTab();
      }
    });
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_reportTab)
      ..dispose();
    super.dispose();
  }

  void _reportTab() => _tabIndex.report(_tabController.index);

  @override
  Widget build(BuildContext context) {
    ref.watch(mobileOverviewTabIndexProvider.notifier);
    return Column(
      key: const Key('mobile-overview-skeleton-page'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MobileOverviewHeader(controller: _tabController),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 横向页签铺到整屏宽，8px 留白放进每个页面内部。这样左右滑动时
              // 页面连同留白边界一起移动，不会像在静态 padding 里替换内容。
              final viewportWidth =
                  constraints.maxWidth +
                  AppPageInsets.compactHorizontal.horizontal;
              return OverflowBox(
                key: const Key('mobile-overview-tab-viewport'),
                minWidth: viewportWidth,
                maxWidth: viewportWidth,
                child: TabBarView(
                  key: const Key('mobile-overview-tab-view'),
                  controller: _tabController,
                  children:
                      const <Widget>[
                            MobileOverviewMyTab(),
                            MobileOverviewClipsTab(),
                            MobileOverviewDiscoverTab(),
                            MobileOverviewMomentsTab(),
                          ]
                          .map(
                            (child) => AppKeepAlive(
                              child: Padding(
                                padding: AppPageInsets.compactHorizontal,
                                child: child,
                              ),
                            ),
                          )
                          .toList(growable: false),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MobileOverviewHeader extends StatelessWidget {
  const _MobileOverviewHeader({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final componentTokens = context.appComponentTokens;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.only(top: spacing.xs, bottom: spacing.sm),
      child: SizedBox(
        height: componentTokens.mobileTopTabHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: AppGlassIconButton(
                key: const Key('mobile-overview-menu-button'),
                tooltip: l10n.overviewOpenMenu,
                semanticLabel: l10n.overviewOpenMenu,
                icon: Icons.menu_rounded,
                // 点击时现取：Scaffold.maybeOf 不建立依赖，drawer 晚挂载时也能打开。
                onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
              ),
            ),
            SizedBox(width: spacing.xs),
            Expanded(
              child: AppTabBar(
                variant: AppTabBarVariant.mobileTop,
                key: const Key('mobile-overview-tabs'),
                controller: controller,
                tabs: [
                  Tab(text: l10n.overviewTabMine),
                  Tab(text: l10n.overviewTabClips),
                  Tab(text: l10n.overviewTabDiscover),
                  Tab(text: l10n.overviewTabMoments),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
