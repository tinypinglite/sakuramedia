import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_fixed_header_layout.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/features/actors/presentation/pages/shared/actor_list_page_behavior.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_summary_scope.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_filter_popover.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_filter_sections.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_list_search_field.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_sort_menu_button.dart';

class DesktopActorsPage extends ConsumerStatefulWidget {
  const DesktopActorsPage({super.key});

  @override
  ConsumerState<DesktopActorsPage> createState() => _DesktopActorsPageState();
}

class _DesktopActorsPageState extends ConsumerState<DesktopActorsPage>
    with ActorListPageBehaviorMixin<DesktopActorsPage> {
  static const _scope = ActorSummaryScope.desktop();

  @override
  ActorSummaryScope get actorScope => _scope;

  @override
  Widget build(BuildContext context) {
    final snapshot = watchActorSnapshot();
    final filter = watchActorFilter();
    final subscriptionUpdating = watchActorSubscriptionUpdating();
    final items = snapshot.items;

    return AppPageRefreshScope(
      onRefresh: refreshActorList,
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
              onRetryFilter: retryActorFilter,
              onFilterChanged: applyActorFilter,
              onResetFilters: resetActorFilters,
              searchExpanded: actorSearchExpanded,
              searchToggle: AppGlassIconButton(
                key: const Key('actors-search-toggle'),
                tooltip: actorSearchExpanded
                    ? AppLocalizations.of(context).actorSearchCollapseTooltip
                    : AppLocalizations.of(context).actorSearchTooltip,
                icon: Icons.search_rounded,
                foregroundColor: actorSearchExpanded || filter.query != null
                    ? Theme.of(context).colorScheme.primary
                    : null,
                onPressed: toggleActorSearch,
              ),
              searchField: ActorListSearchField(
                fieldKey: const Key('actors-search-field'),
                clearButtonKey: const Key('actors-search-clear'),
                controller: actorSearchController,
                onChanged: applyActorSearchQuery,
              ),
            ),
            SizedBox(height: context.appSpacing.lg),
          ],
        ),
        child: AppFilterResultLoadingOverlay(
          isLoading: snapshot.filterUpdate.isLoading,
          hasPreviousItems: items.isNotEmpty,
          child: AppPagedLoadMoreScope(
            canLoadMore: () => canAutoLoadMoreActors,
            onLoadMore: loadMoreActors,
            child: CustomScrollView(
              key: const PageStorageKey<String>('desktop:actors:list'),
              controller: actorScrollController,
              slivers: buildActorListSlivers(
                snapshot: snapshot,
                filter: filter,
                subscriptionUpdating: subscriptionUpdating,
                onActorTap: (actorId) => context.pushDesktopActorDetail(
                  actorId: actorId,
                  fallbackPath: desktopActorsPath,
                ),
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
    final totalLabel = l10n.actorListTotalCount(total);
    if (searchExpanded) {
      return AppGlassListHeader(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppGlassHeaderText(
              key: const Key('actors-page-total'),
              label: totalLabel,
            ),
            SizedBox(width: context.appSpacing.md),
            SizedBox(width: 360, child: searchField),
          ],
        ),
        trailing: searchToggle,
      );
    }
    return AppGlassListHeader(
      leading: AppGlassFilterPopover(
        panelKey: const Key('actors-filter-panel'),
        scrollable: true,
        isDefault: !filterState.hasActiveFilters,
        onReset: onResetFilters,
        triggerKey: const Key('actors-filter-trigger'),
        label: filterState.triggerLabel(l10n),
        info: <Widget>[
          AppGlassHeaderText(
            key: const Key('actors-page-total'),
            label: totalLabel,
          ),
        ],
        panelBuilder: (context) => ActorFilterSectionGroup(
          filterState: filterState,
          onChanged: onFilterChanged,
        ),
      ),
      trailing: AppGlassHeaderGroup(
        children: <Widget>[
          ActorSortMenuButton(
            triggerKey: const Key('actors-sort-trigger'),
            panelKey: const Key('actors-sort-panel'),
            filterState: filterState,
            glassGrouped: true,
            onChanged: onFilterChanged,
          ),
          searchToggle,
        ],
      ),
      filterUpdate: filterUpdate,
      hasPreviousFilterItems: hasPreviousItems,
      onRetryFilter: onRetryFilter,
    );
  }
}
