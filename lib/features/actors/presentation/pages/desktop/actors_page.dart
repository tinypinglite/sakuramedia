import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/cached_page_state_handle.dart';
import 'package:sakuramedia/app/app_page_state_cache_keys.dart';
import 'package:sakuramedia/features/actors/data/api/actors_api.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_list_page_state.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/paged_actor_summary_controller.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_filter_sections.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_summary_grid.dart';

class DesktopActorsPage extends StatefulWidget {
  const DesktopActorsPage({super.key});

  @override
  State<DesktopActorsPage> createState() => _DesktopActorsPageState();
}

class _DesktopActorsPageState extends State<DesktopActorsPage> {
  late final CachedPageStateHandle<ActorListPageStateEntry> _pageStateHandle;

  ActorListPageStateEntry get _pageState => _pageStateHandle.value;

  PagedActorSummaryController get _actorsController => _pageState.controller;
  ActorFilterState get _filterState => _pageState.filterState;

  @override
  void initState() {
    super.initState();
    _pageStateHandle = obtainCachedPageState<ActorListPageStateEntry>(
      context,
      key: desktopActorsPageStateKey(),
      create:
          () => ActorListPageStateEntry(actorsApi: context.read<ActorsApi>()),
    );
  }

  @override
  void dispose() {
    _pageStateHandle.dispose();
    super.dispose();
  }

  void _applyFilter(ActorFilterState nextState) {
    if (nextState.subscriptionStatus == _filterState.subscriptionStatus &&
        nextState.gender == _filterState.gender &&
        nextState.sortField == _filterState.sortField &&
        nextState.sortDirection == _filterState.sortDirection) {
      return;
    }
    setState(() {
      _pageState.filterState = nextState;
    });
    if (_actorsController.scrollController.hasClients) {
      _actorsController.scrollController.jumpTo(0);
    }
    unawaited(_actorsController.reload());
  }

  void _resetFilters() {
    _applyFilter(ActorFilterState.initial);
  }

  Future<void> _toggleActorSubscription(int actorId) async {
    final result = await _actorsController.toggleSubscription(actorId: actorId);
    if (!mounted) {
      return;
    }
    showActorSubscriptionFeedback(result);
  }

  @override
  Widget build(BuildContext context) {
    return AppPageRefreshScope(
      onRefresh: _actorsController.refresh,
      child: ColoredBox(
        color: context.appColors.surfaceElevated,
        child: CustomScrollView(
          controller: _actorsController.scrollController,
          slivers: [
            AnimatedBuilder(
              animation: _actorsController,
              builder: (context, _) {
                final showFooter =
                    _actorsController.items.isNotEmpty &&
                    (_actorsController.isLoadingMore ||
                        _actorsController.loadMoreErrorMessage != null);
                return SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        key: const Key('actors-page'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ActorsHeader(
                            total: _actorsController.total,
                            filterState: _filterState,
                            onFilterChanged: _applyFilter,
                            onResetFilters: _resetFilters,
                          ),
                          SizedBox(height: context.appSpacing.lg),
                        ],
                      ),
                    ),
                    ActorSummarySliver(
                      items: _actorsController.items,
                      isLoading: _actorsController.isInitialLoading,
                      errorMessage: _actorsController.initialErrorMessage,
                      onActorTap:
                          (actor) => context.pushDesktopActorDetail(
                            actorId: actor.id,
                            fallbackPath: desktopActorsPath,
                          ),
                      onActorSubscriptionTap:
                          (actor) => _toggleActorSubscription(actor.id),
                      isActorSubscriptionUpdating:
                          (actor) => _actorsController.isSubscriptionUpdating(
                            actor.id,
                          ),
                      emptyMessage:
                          _filterState.isDefault
                              ? '暂无女优，去搜索看看吧'
                              : '当前筛选条件下暂无匹配女优',
                    ),
                    if (showFooter)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(top: context.appSpacing.md),
                          child: AppPagedLoadMoreFooter(
                            isLoading: _actorsController.isLoadingMore,
                            errorMessage:
                                _actorsController.loadMoreErrorMessage,
                            onRetry: _actorsController.loadMore,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

}

class _ActorsHeader extends StatelessWidget {
  const _ActorsHeader({
    required this.total,
    required this.filterState,
    required this.onFilterChanged,
    required this.onResetFilters,
  });

  final int total;
  final ActorFilterState filterState;
  final ValueChanged<ActorFilterState> onFilterChanged;
  final VoidCallback onResetFilters;

  @override
  Widget build(BuildContext context) {
    // 与移动女优页共用同一条顶栏，差别只在筛选面板的容器：
    // 桌面就地浮层，移动底部抽屉（见 `showMobileActorFilterDrawer`）。
    return AppListHeader(
      filterButtonKey: const Key('actors-filter-trigger'),
      filterLabel: filterState.triggerLabel,
      filterPanelKey: const Key('actors-filter-panel'),
      filterPanelExtraWidth: 180,
      filterPanelBuilder:
          (_) => ActorFilterSectionGroup(
            filterState: filterState,
            onChanged: onFilterChanged,
          ),
      filterPanelFooter: AppFilterPanelFooter(
        isDefault: filterState.isDefault,
        onReset: onResetFilters,
      ),
      informationSlots: [
        AppListHeaderInfo(
          key: const Key('actors-page-total'),
          label: '$total 位',
        ),
      ],
    );
  }
}
