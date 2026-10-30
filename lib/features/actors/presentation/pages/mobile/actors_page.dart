import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_fixed_header_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/page_cache_keys.dart';
import 'package:sakuramedia/app/providers/riverpod_page_cache_provider.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/features/actors/presentation/pages/mobile/actor_filter_drawer.dart';
import 'package:sakuramedia/features/actors/presentation/actor_placeholders.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_summary_provider.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_summary_scope.dart';
import 'package:sakuramedia/features/actors/presentation/widgets/actor_taste_recommendation_rail.dart';
import 'package:sakuramedia/features/discovery/presentation/providers/taste_profile_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_view_snapshot.dart';
import 'package:sakuramedia/features/shared/presentation/providers/stable_set_selection.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_list_search_field.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_sort_menu_button.dart';
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
  late final TextEditingController _searchController;

  bool _searchExpanded = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _searchController = TextEditingController(
      text: ref.read(actorSummaryProvider(_scope)).value?.filter.query ?? '',
    );
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
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _applyFilter(ActorFilterState nextState) {
    final current = ref.read(actorSummaryProvider(_scope)).value?.filter;
    if (current == nextState) {
      return;
    }
    if ((nextState.query ?? '').isEmpty && _searchController.text.isNotEmpty) {
      _searchController.clear();
    }
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    unawaited(
      ref.read(actorSummaryProvider(_scope).notifier).applyFilter(nextState),
    );
  }

  void _applySearchQuery(String value) {
    final current =
        ref.read(actorSummaryProvider(_scope)).value?.filter ??
        ActorFilterState.initial;
    _applyFilter(current.withSearchQuery(value));
  }

  void _toggleSearch() {
    setState(() => _searchExpanded = !_searchExpanded);
  }

  Future<void> _toggleActorSubscription(int actorId) async {
    final result = await ref
        .read(actorSummaryProvider(_scope).notifier)
        .toggleSubscription(actorId);
    if (!mounted) {
      return;
    }
    showActorSubscriptionFeedback(result, l10n: AppLocalizations.of(context));
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(
      actorSummaryProvider(
        _scope,
      ).select((state) => pagedViewSnapshot(state, (summary) => summary.paged)),
    );
    final filter = ref.watch(
      actorSummaryProvider(
        _scope,
      ).select((state) => state.value?.filter ?? ActorFilterState.initial),
    );
    final subscriptionUpdating = ref.watch(
      actorSummaryProvider(_scope).select(
        (state) => StableSetSelection<int>(
          state.value?.subscriptionUpdatingActorIds ?? const <int>{},
        ),
      ),
    );
    final items = snapshot.items;
    final initialErrorMessage = snapshot.initialError != null
        ? AppLocalizations.of(context).errorActorListLoadFailed
        : null;

    return ColoredBox(
      color: context.appColors.surfaceCard,
      child: AppFixedHeaderLayout(
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppListHeader(
              filterButtonKey: const Key('mobile-actors-filter-button'),
              filterTooltip: AppLocalizations.of(context).actorFilterTooltip,
              filterLabel: filter.triggerLabel(AppLocalizations.of(context)),
              onFilterTap: _openFilterDrawer,
              filterUpdate: snapshot.filterUpdate,
              hasPreviousFilterItems: items.isNotEmpty,
              onRetryFilter: () => unawaited(
                ref.read(actorSummaryProvider(_scope).notifier).retryFilter(),
              ),
              informationSlots: _searchExpanded
                  ? const <Widget>[]
                  : <Widget>[
                      AppListHeaderInfo(
                        key: const Key('mobile-actors-total'),
                        label: AppLocalizations.of(
                          context,
                        ).actorListTotalCount(snapshot.total),
                      ),
                    ],
              actionSlots: _searchExpanded
                  ? const <Widget>[]
                  : <Widget>[
                      ActorSortMenuButton(
                        triggerKey: const Key('mobile-actors-sort-trigger'),
                        drawerKey: const Key('mobile-actors-sort-drawer'),
                        keyPrefix: 'mobile-actors',
                        filterState: filter,
                        onChanged: _applyFilter,
                        useDrawer: true,
                      ),
                      ActorListSearchToggle(
                        key: const Key('mobile-actors-search-toggle'),
                        isActive: _searchExpanded || filter.query != null,
                        tooltip: _searchExpanded
                            ? AppLocalizations.of(
                                context,
                              ).actorSearchCollapseTooltip
                            : AppLocalizations.of(context).actorSearchTooltip,
                        onTap: _toggleSearch,
                      ),
                    ],
              center: _searchExpanded
                  ? Row(
                      children: [
                        Expanded(
                          child: ActorListSearchField(
                            fieldKey: const Key('mobile-actors-search-field'),
                            clearButtonKey: const Key(
                              'mobile-actors-search-clear',
                            ),
                            controller: _searchController,
                            onChanged: _applySearchQuery,
                          ),
                        ),
                        SizedBox(width: context.appSpacing.sm),
                        ActorListSearchToggle(
                          key: const Key('mobile-actors-search-toggle'),
                          isActive: true,
                          tooltip: AppLocalizations.of(
                            context,
                          ).actorSearchCollapseTooltip,
                          onTap: _toggleSearch,
                        ),
                      ],
                    )
                  : null,
            ),
            SizedBox(height: context.appSpacing.md),
          ],
        ),
        child: AppFilterResultLoadingOverlay(
          surfaceColor: context.appColors.surfaceCard,
          isLoading: snapshot.filterUpdate.isLoading,
          hasPreviousItems: items.isNotEmpty,
          child: AppPagedLoadMoreScope(
            canLoadMore: () =>
                ref
                    .read(actorSummaryProvider(_scope))
                    .value
                    ?.paged
                    .canAutoLoadMore ??
                false,
            onLoadMore: () =>
                ref.read(actorSummaryProvider(_scope).notifier).loadMore(),
            child: AppAdaptiveRefreshScrollView(
              key: const PageStorageKey<String>('mobile:actors:list'),
              onRefresh: _handleRefresh,
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                if (!filter.hasActiveFilters)
                  SliverToBoxAdapter(
                    child: ActorTasteRecommendationRail(
                      onActorTap: (actorId) => MobileActorDetailRouteData(
                        actorId: actorId,
                      ).push(context),
                    ),
                  ),
                SliverMainAxisGroup(
                  key: const Key('mobile-actors-page'),
                  slivers: [
                    if (!snapshot.filterUpdate.hasFailed || items.isNotEmpty)
                      AppSkeletonizer.sliver(
                        enabled: snapshot.isInitialLoading,
                        child: ActorSummarySliver(
                          items: snapshot.isInitialLoading
                              ? actorListItemPlaceholders(count: 24)
                              : items,
                          errorMessage: initialErrorMessage,
                          onActorTap: (actor) => MobileActorDetailRouteData(
                            actorId: actor.id,
                          ).push(context),
                          onActorSubscriptionTap: (actor) =>
                              _toggleActorSubscription(actor.id),
                          isActorSubscriptionUpdating: (actor) =>
                              subscriptionUpdating.contains(actor.id),
                          emptyMessage: !filter.hasActiveFilters
                              ? AppLocalizations.of(context).actorListEmpty
                              : AppLocalizations.of(
                                  context,
                                ).actorListEmptyFiltered,
                        ),
                      ),
                    // loadMore 页脚独立订阅：翻页 loading / 失败只重建页脚。
                    PagedLoadMoreFooterSliver(
                      watchFooter: (ref) => ref.watch(
                        actorSummaryProvider(_scope).select(
                          (s) => pagedLoadMoreFooterSnapshot(s.value?.paged),
                        ),
                      ),
                      onLoadMore: (ref) => unawaited(
                        ref
                            .read(actorSummaryProvider(_scope).notifier)
                            .loadMore(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    final error = await ref
        .read(actorSummaryProvider(_scope).notifier)
        .refresh();
    await ref.read(tasteProfileProvider.notifier).refresh();
    if (error != null && mounted) {
      showToast(AppLocalizations.of(context).actorRefreshFailed);
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
