import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/page_cache_keys.dart';
import 'package:sakuramedia/app/providers/riverpod_page_cache_provider.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/features/actors/presentation/pages/mobile/actor_filter_drawer.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_summary_provider.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_summary_scope.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_summary_grid.dart';

class MobileActorsPage extends ConsumerStatefulWidget {
  const MobileActorsPage({super.key});

  @override
  ConsumerState<MobileActorsPage> createState() => _MobileActorsPageState();
}

class _MobileActorsPageState extends ConsumerState<MobileActorsPage> {
  static const _scope = ActorSummaryScope.mobile();

  late final RiverpodPageHandle _pageCacheHandle;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_loadMoreIfNeeded);
    _pageCacheHandle = ref
        .read(riverpodPageCacheProvider)
        .obtain(
          key: mobileActorsPageCacheKey(),
          resolveLinks: () {
            final link = ref
                .read(actorSummaryProvider(_scope).notifier)
                .cacheLink;
            return link == null ? const [] : [link];
          },
        );
  }

  @override
  void dispose() {
    _pageCacheHandle.release();
    _scrollController
      ..removeListener(_loadMoreIfNeeded)
      ..dispose();
    super.dispose();
  }

  void _loadMoreIfNeeded() {
    if (!_scrollController.hasClients) {
      return;
    }
    final summary = ref.read(actorSummaryProvider(_scope)).value;
    final position = _scrollController.position;
    if (summary == null ||
        summary.paged.loadMoreErrorMessage != null ||
        position.pixels < position.maxScrollExtent - 300) {
      return;
    }
    unawaited(ref.read(actorSummaryProvider(_scope).notifier).loadMore());
  }

  void _applyFilter(ActorFilterState nextState) {
    final current = ref.read(actorSummaryProvider(_scope)).value?.filter;
    if (current == nextState) {
      return;
    }
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    unawaited(
      ref.read(actorSummaryProvider(_scope).notifier).applyFilter(nextState),
    );
  }

  Future<void> _toggleActorSubscription(int actorId) async {
    final result = await ref
        .read(actorSummaryProvider(_scope).notifier)
        .toggleSubscription(actorId);
    if (!mounted) {
      return;
    }
    showActorSubscriptionFeedback(result);
  }

  @override
  Widget build(BuildContext context) {
    final actorsAsync = ref.watch(actorSummaryProvider(_scope));
    final summary = actorsAsync.value;
    final paged = summary?.paged;
    final filter = summary?.filter ?? ActorFilterState.initial;
    final items = paged?.items ?? const [];
    final isInitialLoading = actorsAsync.isLoading && summary == null;
    final initialErrorMessage = actorsAsync.hasError && summary == null
        ? '女优列表加载失败，请稍后重试'
        : null;
    final showFooter =
        items.isNotEmpty &&
        (paged!.isLoadingMore || paged.loadMoreErrorMessage != null);

    return ColoredBox(
      color: context.appColors.surfaceCard,
      child: AppFilterResultLoadingOverlay(
        isLoading: paged?.filterUpdate.isLoading ?? false,
        hasPreviousItems: items.isNotEmpty,
        child: AppAdaptiveRefreshScrollView(
          key: const PageStorageKey<String>('mobile:actors:list'),
          onRefresh: _handleRefresh,
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverMainAxisGroup(
              key: const Key('mobile-actors-page'),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppListHeader(
                        filterButtonKey: const Key(
                          'mobile-actors-filter-button',
                        ),
                        filterTooltip: '筛选',
                        filterLabel: filter.triggerLabel,
                        onFilterTap: _openFilterDrawer,
                        filterUpdate:
                            paged?.filterUpdate ??
                            const FilterUpdateState.idle(),
                        hasPreviousFilterItems: items.isNotEmpty,
                        onRetryFilter: () => unawaited(
                          ref
                              .read(actorSummaryProvider(_scope).notifier)
                              .retryFilter(),
                        ),
                        informationSlots: [
                          AppListHeaderInfo(
                            key: const Key('mobile-actors-total'),
                            label: '${paged?.total ?? 0} 位',
                          ),
                        ],
                      ),
                      SizedBox(height: context.appSpacing.md),
                    ],
                  ),
                ),
                if (!(paged?.filterUpdate.hasFailed ?? false) ||
                    items.isNotEmpty)
                  ActorSummarySliver(
                    items: items,
                    isLoading: isInitialLoading,
                    errorMessage: initialErrorMessage,
                    onActorTap: (actor) => MobileActorDetailRouteData(
                      actorId: actor.id,
                    ).push(context),
                    onActorSubscriptionTap: (actor) =>
                        _toggleActorSubscription(actor.id),
                    isActorSubscriptionUpdating: (actor) =>
                        summary?.isSubscriptionUpdating(actor.id) ?? false,
                    emptyMessage: filter.isDefault
                        ? '暂无女优，去搜索看看吧'
                        : '当前筛选条件下暂无匹配女优',
                  ),
                if (showFooter)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: context.appSpacing.md),
                      child: AppPagedLoadMoreFooter(
                        isLoading: paged.isLoadingMore,
                        errorMessage: paged.loadMoreErrorMessage,
                        onRetry: () => ref
                            .read(actorSummaryProvider(_scope).notifier)
                            .loadMore(),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    final error = await ref
        .read(actorSummaryProvider(_scope).notifier)
        .refresh();
    if (error != null && mounted) {
      showToast('刷新失败');
    }
  }

  Future<void> _openFilterDrawer() async {
    final current =
        ref.read(actorSummaryProvider(_scope)).value?.filter ??
        ActorFilterState.initial;
    await showMobileActorFilterDrawer(
      context,
      current: current,
      onChanged: _applyFilter,
    );
  }
}
