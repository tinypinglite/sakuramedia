import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/features/actors/presentation/pages/mobile/actor_filter_drawer.dart';
import 'package:sakuramedia/features/actors/presentation/pages/shared/actor_list_page_behavior.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_summary_provider.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_summary_scope.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_view_snapshot.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pinned_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_list_header.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_list_search_field.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_sort_menu_button.dart';

class MobileActorsPage extends ConsumerStatefulWidget {
  const MobileActorsPage({super.key});

  @override
  ConsumerState<MobileActorsPage> createState() => _MobileActorsPageState();
}

class _MobileActorsPageState extends ConsumerState<MobileActorsPage>
    with ActorListPageBehaviorMixin<MobileActorsPage> {
  static const _scope = ActorSummaryScope.mobile();

  @override
  ActorSummaryScope get actorScope => _scope;

  @override
  Widget build(BuildContext context) {
    final snapshot = watchActorSnapshot();
    final filter = watchActorFilter();
    final subscriptionUpdating = watchActorSubscriptionUpdating();

    return AppFilterResultLoadingOverlay(
      surfaceColor: context.appColors.surfaceCard.withValues(alpha: 0.9),
      protectedHeaderKey: actorListHeaderKey,
      scrollController: actorScrollController,
      isLoading: snapshot.filterUpdate.isLoading,
      hasPreviousItems: snapshot.items.isNotEmpty,
      child: AppPagedLoadMoreScope(
        canLoadMore: () => canAutoLoadMoreActors,
        onLoadMore: loadMoreActors,
        child: AppAdaptiveRefreshScrollView(
          key: const PageStorageKey<String>('mobile:actors:list'),
          onRefresh: refreshActorList,
          controller: actorScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            AppPinnedSliverSection(
              key: const Key('mobile-actors-page'),
              headerKey: actorListHeaderKey,
              before: <Widget>[
                SliverToBoxAdapter(
                  child: AppMobilePageTitle(
                    key: const Key('mobile-actors-large-title'),
                    title: AppLocalizations.of(context).routeActorsTitle,
                  ),
                ),
              ],
              header: _buildHeader(context, snapshot, filter),
              headerBottomSpacing: context.appSpacing.md,
              after: buildActorListSlivers(
                snapshot: snapshot,
                filter: filter,
                subscriptionUpdating: subscriptionUpdating,
                onActorTap: (actorId) =>
                    MobileRoutes.actorDetail(actorId: actorId).push(context),
                sliverGroupKey: const Key('mobile-actors-page'),
              ),
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
  ) {
    final l10n = AppLocalizations.of(context);
    return AppMobileListHeader(
      leading: actorSearchExpanded
          ? ActorListSearchField(
              fieldKey: const Key('mobile-actors-search-field'),
              clearButtonKey: const Key('mobile-actors-search-clear'),
              controller: actorSearchController,
              onChanged: applyActorSearchQuery,
            )
          : AppMobileHeaderText(
              key: const Key('mobile-actors-total'),
              title: l10n.actorListAllTitle,
              countLabel: l10n.actorListTotalCount(snapshot.total),
            ),
      actions: actorSearchExpanded
          ? <Widget>[
              ActorListSearchToggle(
                key: const Key('mobile-actors-search-toggle'),
                isActive: true,
                tooltip: l10n.actorSearchCollapseTooltip,
                onTap: toggleActorSearch,
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
                onChanged: applyActorFilter,
                useDrawer: true,
                iconOnly: true,
              ),
              ActorListSearchToggle(
                key: const Key('mobile-actors-search-toggle'),
                isActive: filter.query != null,
                tooltip: l10n.actorSearchTooltip,
                onTap: toggleActorSearch,
              ),
            ],
      filterUpdate: snapshot.filterUpdate,
      hasPreviousFilterItems: snapshot.items.isNotEmpty,
      onRetryFilter: retryActorFilter,
    );
  }

  Future<void> _openFilterDrawer() async {
    final current =
        ref.read(actorSummaryProvider(_scope)).value?.filter ??
        ActorFilterState.initial;
    await showMobileActorFilterDrawer(
      context,
      current: current,
      onChanged: applyActorFilter,
    );
  }
}
