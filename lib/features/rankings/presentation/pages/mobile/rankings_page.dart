import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/rankings/presentation/pages/mobile/ranking_filter_drawer.dart';
import 'package:sakuramedia/features/rankings/presentation/pages/shared/rankings_page_behavior.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/ranking_summary_scope.dart';
import 'package:sakuramedia/features/rankings/presentation/widgets/ranking_filter_sections.dart';
import 'package:sakuramedia/features/shared/data/movie_interaction_filter.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pinned_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_list_header.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_batch_selection.dart';
import 'package:sakuramedia/widgets/domain/rankings/ranking_sort_menu_button.dart';

class MobileRankingsPage extends ConsumerStatefulWidget {
  const MobileRankingsPage({super.key});

  @override
  ConsumerState<MobileRankingsPage> createState() => _MobileRankingsPageState();
}

class _MobileRankingsPageState extends ConsumerState<MobileRankingsPage>
    with
        MultiSelectStateMixin<MobileRankingsPage, String>,
        MovieBatchSelectionMixin<MobileRankingsPage>,
        RankingsPageBehaviorMixin<MobileRankingsPage> {
  static const _scope = RankingSummaryScope.mobile();

  @override
  RankingSummaryScope get rankingScope => _scope;

  @override
  Widget build(BuildContext context) {
    final view = watchRankingsPage();
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    return Column(
      children: [
        Expanded(
          child: AppFilterResultLoadingOverlay(
            surfaceColor: highContrast
                ? context.appColors.surfacePage
                : context.appColors.surfaceCard.withValues(alpha: 0.9),
            protectedHeaderKey: rankingsHeaderKey,
            scrollController: rankingsScrollController,
            isLoading: view.paged.filterUpdate.isLoading,
            hasPreviousItems: view.paged.items.isNotEmpty,
            child: _buildScrollView(context, view),
          ),
        ),
        // 多选态的批量动作贴底常驻，与影片列表 / PornBox 一致。
        if (selectionMode) buildMobileBatchSelectionBottomBar(),
      ],
    );
  }

  Widget _buildScrollView(BuildContext context, RankingsPageView view) {
    final l10n = AppLocalizations.of(context);
    final errorBanner = buildRankingFilterErrorBanner(view);
    return AppPagedLoadMoreScope(
      canLoadMore: () => canAutoLoadMoreRankings,
      onLoadMore: loadMoreRankings,
      child: AppAdaptiveRefreshScrollView(
        key: const PageStorageKey<String>('mobile:rankings:list'),
        onRefresh: refreshRankings,
        controller: rankingsScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          AppPinnedSliverSection(
            key: const Key('mobile-rankings-page'),
            headerKey: rankingsHeaderKey,
            before: <Widget>[
              SliverToBoxAdapter(
                child: AppMobilePageTitle(
                  key: const Key('mobile-rankings-large-title'),
                  title: l10n.routeRankingsBoardTitle,
                ),
              ),
            ],
            header: selectionMode
                ? buildMobileBatchSelectionHeader()
                : _buildHeader(context, view),
            headerBottomSpacing: context.appSpacing.md,
            after: <Widget>[
              if (errorBanner != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: context.appSpacing.md),
                    child: errorBanner,
                  ),
                ),
              ...buildRankingListSlivers(view),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, RankingsPageView view) {
    final l10n = AppLocalizations.of(context);
    final filters = view.filters;
    final boardLabel = rankingBoardLabel(filters, l10n);
    final syncedAtLabel = rankingSyncedAtLabel(view.syncedAt, l10n);
    final filterActive =
        filters.selectedSource != null ||
        filters.selectedBoard != null ||
        filters.selectedPeriod != null ||
        filters.interaction != MovieInteractionFilter.initial;
    return AppMobileListHeader(
      leading: AppMobileHeaderText(
        key: const Key('mobile-rankings-page-total'),
        title: l10n.rankingListMoviesTitle,
        countLabel: l10n.sharedMovieCount(view.paged.total),
        secondaryLabel: syncedAtLabel,
        secondaryKey: const Key('mobile-rankings-synced-at'),
      ),
      actions: <Widget>[
        AppGlassFilterIconButton(
          key: const Key('mobile-rankings-filter-button'),
          summary: boardLabel,
          isActive: filterActive,
          onPressed: filters.sources.isEmpty
              ? null
              : () => _openFilterDrawer(initialAnchor: null),
        ),
        RankingSortMenuButton(
          triggerKey: const Key('mobile-rankings-sort-trigger'),
          drawerKey: const Key('mobile-rankings-sort-drawer'),
          keyPrefix: 'mobile-rankings',
          filterState: filters,
          useDrawer: true,
          iconOnly: true,
          onSortChanged: selectRankingSort,
        ),
      ],
      filterUpdate: view.paged.filterUpdate,
      hasPreviousFilterItems: view.paged.items.isNotEmpty,
      onRetryFilter: retryRankingFilter,
    );
  }

  Future<void> _openFilterDrawer({RankingFilterAnchor? initialAnchor}) async {
    await showMobileRankingFilterDrawer(
      context,
      scope: _scope,
      actions: rankingFilterActions,
      initialAnchor: initialAnchor,
    );
  }
}
