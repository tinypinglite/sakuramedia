import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/app/page_cache_keys.dart';
import 'package:sakuramedia/app/providers/riverpod_page_cache_provider.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
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
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pinned_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_list_header.dart';
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
  final _listHeaderKey = GlobalKey();

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

    return AppFilterResultLoadingOverlay(
      surfaceColor: context.appColors.surfaceCard.withValues(alpha: 0.9),
      protectedHeaderKey: _listHeaderKey,
      scrollController: _scrollController,
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
            AppPinnedSliverSection(
              key: const Key('mobile-actors-page'),
              headerKey: _listHeaderKey,
              before: <Widget>[
                SliverToBoxAdapter(
                  child: AppMobilePageTitle(
                    key: const Key('mobile-actors-large-title'),
                    title: AppLocalizations.of(context).routeActorsTitle,
                  ),
                ),
              ],
              header: _buildHeader(context, snapshot, filter, items),
              headerBottomSpacing: context.appSpacing.md,
              after: <Widget>[
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
                  slivers: <Widget>[
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
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    PagedViewSnapshot<ActorListItemDto> snapshot,
    ActorFilterState filter,
    List<ActorListItemDto> items,
  ) {
    final l10n = AppLocalizations.of(context);
    return AppMobileListHeader(
      leading: _searchExpanded
          ? ActorListSearchField(
              fieldKey: const Key('mobile-actors-search-field'),
              clearButtonKey: const Key('mobile-actors-search-clear'),
              controller: _searchController,
              onChanged: _applySearchQuery,
            )
          : AppMobileHeaderText(
              key: const Key('mobile-actors-total'),
              title: l10n.actorListAllTitle,
              countLabel: l10n.actorListTotalCount(snapshot.total),
            ),
      actions: _searchExpanded
          ? <Widget>[
              ActorListSearchToggle(
                key: const Key('mobile-actors-search-toggle'),
                isActive: true,
                tooltip: l10n.actorSearchCollapseTooltip,
                onTap: _toggleSearch,
              ),
            ]
          : <Widget>[
              AppGlassFilterIconButton(
                key: const Key('mobile-actors-filter-button'),
                summary: filter.triggerLabel(l10n),
                isActive: filter.hasActiveFilters,
                onPressed: _openFilterDrawer,
              ),
              ActorSortMenuButton(
                triggerKey: const Key('mobile-actors-sort-trigger'),
                drawerKey: const Key('mobile-actors-sort-drawer'),
                keyPrefix: 'mobile-actors',
                filterState: filter,
                onChanged: _applyFilter,
                useDrawer: true,
                iconOnly: true,
              ),
              ActorListSearchToggle(
                key: const Key('mobile-actors-search-toggle'),
                isActive: filter.query != null,
                tooltip: l10n.actorSearchTooltip,
                onTap: _toggleSearch,
              ),
            ],
      filterUpdate: snapshot.filterUpdate,
      hasPreviousFilterItems: items.isNotEmpty,
      onRetryFilter: () => unawaited(
        ref.read(actorSummaryProvider(_scope).notifier).retryFilter(),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    final error = await ref
        .read(actorSummaryProvider(_scope).notifier)
        .refresh();
    await ref.read(tasteProfileProvider.notifier).refresh();
    if (error != null && mounted) {
      showToast(
        AppLocalizations.of(context).actorRefreshFailed,
        tone: AppToastTone.error,
      );
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
