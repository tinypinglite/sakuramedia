import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/cached_page_state_handle.dart';
import 'package:sakuramedia/app/app_page_state_cache_keys.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/actors/presentation/actor_list_page_state.dart';
import 'package:sakuramedia/features/actors/presentation/actor_filter_state.dart';
import 'package:sakuramedia/features/actors/presentation/paged_actor_summary_controller.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_filter_total_header.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/widgets/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/actors/actor_filter_toolbar.dart';
import 'package:sakuramedia/widgets/actors/actor_summary_grid.dart';

class MobileActorsPage extends StatefulWidget {
  const MobileActorsPage({super.key});

  @override
  State<MobileActorsPage> createState() => _MobileActorsPageState();
}

class _MobileActorsPageState extends State<MobileActorsPage> {
  late final CachedPageStateHandle<ActorListPageStateEntry> _pageStateHandle;

  ActorListPageStateEntry get _pageState => _pageStateHandle.value;

  PagedActorSummaryController get _actorsController => _pageState.controller;
  ActorFilterState get _filterState => _pageState.filterState;

  @override
  void initState() {
    super.initState();
    _pageStateHandle = obtainCachedPageState<ActorListPageStateEntry>(
      context,
      key: mobileActorsPageStateKey(),
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
        nextState.gender == _filterState.gender) {
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
    return ColoredBox(
      color: context.appColors.surfaceCard,
      child: AppAdaptiveRefreshScrollView(
        onRefresh: _handleRefresh,
        controller: _actorsController.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _actorsController,
              builder: (context, _) {
                final showFooter =
                    _actorsController.items.isNotEmpty &&
                    (_actorsController.isLoadingMore ||
                        _actorsController.loadMoreErrorMessage != null);
                return Column(
                  key: const Key('mobile-actors-page'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppFilterTotalHeader(
                      leading: ActorFilterToolbar(
                        filterState: _filterState,
                        onChanged: _applyFilter,
                        onReset: _resetFilters,
                      ),
                      totalText: '${_actorsController.total} 位',
                      totalKey: const Key('mobile-actors-page-total'),
                    ),
                    SizedBox(height: context.appSpacing.md),
                    ActorSummaryGrid(
                      items: _actorsController.items,
                      isLoading: _actorsController.isInitialLoading,
                      errorMessage: _actorsController.initialErrorMessage,
                      onActorTap:
                          (actor) => MobileActorDetailRouteData(
                            actorId: actor.id,
                          ).push(context),
                      onActorSubscriptionTap:
                          (actor) => _toggleActorSubscription(actor.id),
                      isActorSubscriptionUpdating:
                          (actor) => _actorsController.isSubscriptionUpdating(
                            actor.id,
                          ),
                      emptyMessage: '暂无女优数据',
                    ),
                    if (showFooter) ...[
                      SizedBox(height: context.appSpacing.md),
                      AppPagedLoadMoreFooter(
                        isLoading: _actorsController.isLoadingMore,
                        errorMessage: _actorsController.loadMoreErrorMessage,
                        onRetry: _actorsController.loadMore,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRefresh() async {
    try {
      await _actorsController.refresh();
    } catch (_) {
      if (mounted) {
        showToast('刷新失败');
      }
    }
  }
}
