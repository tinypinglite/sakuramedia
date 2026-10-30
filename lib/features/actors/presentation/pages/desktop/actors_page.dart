import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_fixed_header_layout.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/page_cache_keys.dart';
import 'package:sakuramedia/app/providers/riverpod_page_cache_provider.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/features/actors/presentation/actor_placeholders.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_summary_provider.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_summary_scope.dart';
import 'package:sakuramedia/features/actors/presentation/widgets/actor_taste_recommendation_rail.dart';
import 'package:sakuramedia/features/discovery/presentation/providers/taste_profile_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_view_snapshot.dart';
import 'package:sakuramedia/features/shared/presentation/providers/stable_set_selection.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_filter_sections.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_list_search_field.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_sort_menu_button.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_summary_grid.dart';

class DesktopActorsPage extends ConsumerStatefulWidget {
  const DesktopActorsPage({super.key});

  @override
  ConsumerState<DesktopActorsPage> createState() => _DesktopActorsPageState();
}

class _DesktopActorsPageState extends ConsumerState<DesktopActorsPage> {
  static const _scope = ActorSummaryScope.desktop();

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
          key: desktopActorsPageCacheKey(),
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

  void _resetFilters() {
    final current =
        ref.read(actorSummaryProvider(_scope)).value?.filter ??
        ActorFilterState.initial;
    _applyFilter(current.resetFilters());
  }

  Future<void> _refresh() async {
    await Future.wait<void>([
      ref.read(actorSummaryProvider(_scope).notifier).refresh(),
      ref.read(tasteProfileProvider.notifier).refresh(),
    ]);
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

    return AppPageRefreshScope(
      onRefresh: _refresh,
      child: ColoredBox(
        color: context.appColors.surfaceElevated,
        child: AppFixedHeaderLayout(
          header: Column(
            key: const Key('actors-page'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ActorsHeader(
                total: snapshot.total,
                filterState: filter,
                filterUpdate: snapshot.filterUpdate,
                hasPreviousItems: items.isNotEmpty,
                onRetryFilter: () => unawaited(
                  ref.read(actorSummaryProvider(_scope).notifier).retryFilter(),
                ),
                onFilterChanged: _applyFilter,
                onResetFilters: _resetFilters,
                searchExpanded: _searchExpanded,
                searchToggle: ActorListSearchToggle(
                  key: const Key('actors-search-toggle'),
                  isActive: _searchExpanded || filter.query != null,
                  tooltip: _searchExpanded
                      ? AppLocalizations.of(context).actorSearchCollapseTooltip
                      : AppLocalizations.of(context).actorSearchTooltip,
                  onTap: _toggleSearch,
                ),
                searchField: ActorListSearchField(
                  fieldKey: const Key('actors-search-field'),
                  clearButtonKey: const Key('actors-search-clear'),
                  controller: _searchController,
                  onChanged: _applySearchQuery,
                ),
              ),
              SizedBox(height: context.appSpacing.lg),
            ],
          ),
          child: AppFilterResultLoadingOverlay(
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
              child: CustomScrollView(
                key: const PageStorageKey<String>('desktop:actors:list'),
                controller: _scrollController,
                slivers: [
                  if (!filter.hasActiveFilters)
                    SliverToBoxAdapter(
                      child: ActorTasteRecommendationRail(
                        onActorTap: (actorId) => context.pushDesktopActorDetail(
                          actorId: actorId,
                          fallbackPath: desktopActorsPath,
                        ),
                      ),
                    ),
                  SliverMainAxisGroup(
                    slivers: [
                      if (!snapshot.filterUpdate.hasFailed || items.isNotEmpty)
                        AppSkeletonizer.sliver(
                          enabled: snapshot.isInitialLoading,
                          child: ActorSummarySliver(
                            items: snapshot.isInitialLoading
                                ? actorListItemPlaceholders(count: 24)
                                : items,
                            errorMessage: initialErrorMessage,
                            onActorTap: (actor) =>
                                context.pushDesktopActorDetail(
                                  actorId: actor.id,
                                  fallbackPath: desktopActorsPath,
                                ),
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
      ),
    );
  }
}

class _ActorsHeader extends StatelessWidget {
  const _ActorsHeader({
    required this.total,
    required this.filterState,
    required this.filterUpdate,
    required this.hasPreviousItems,
    required this.onRetryFilter,
    required this.onFilterChanged,
    required this.onResetFilters,
    required this.searchExpanded,
    required this.searchToggle,
    required this.searchField,
  });

  final int total;
  final ActorFilterState filterState;
  final FilterUpdateState filterUpdate;
  final bool hasPreviousItems;
  final VoidCallback onRetryFilter;
  final ValueChanged<ActorFilterState> onFilterChanged;
  final VoidCallback onResetFilters;
  final bool searchExpanded;
  final Widget searchToggle;
  final Widget searchField;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppListHeader(
      filterButtonKey: const Key('actors-filter-trigger'),
      filterLabel: filterState.triggerLabel(l10n),
      filterPanelKey: const Key('actors-filter-panel'),
      filterPanelExtraWidth: 260,
      filterPanelBuilder: (_) => ActorFilterSectionGroup(
        filterState: filterState,
        onChanged: onFilterChanged,
      ),
      filterPanelFooter: AppFilterPanelFooter(
        isDefault: !filterState.hasActiveFilters,
        onReset: onResetFilters,
      ),
      filterUpdate: filterUpdate,
      hasPreviousFilterItems: hasPreviousItems,
      onRetryFilter: onRetryFilter,
      informationSlots: searchExpanded
          ? const <Widget>[]
          : <Widget>[
              AppListHeaderInfo(
                key: const Key('actors-page-total'),
                label: l10n.actorListTotalCount(total),
              ),
            ],
      actionSlots: searchExpanded
          ? const <Widget>[]
          : <Widget>[
              ActorSortMenuButton(
                triggerKey: const Key('actors-sort-trigger'),
                panelKey: const Key('actors-sort-panel'),
                filterState: filterState,
                onChanged: onFilterChanged,
              ),
              searchToggle,
            ],
      center: searchExpanded
          ? Row(
              children: [
                AppListHeaderInfo(
                  key: const Key('actors-page-total'),
                  label: l10n.actorListTotalCount(total),
                ),
                const Spacer(),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Row(
                    children: [
                      Expanded(child: searchField),
                      SizedBox(width: context.appSpacing.sm),
                      searchToggle,
                    ],
                  ),
                ),
              ],
            )
          : null,
    );
  }
}
