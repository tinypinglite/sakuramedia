import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/rankings/presentation/pages/shared/rankings_page_behavior.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/ranking_summary_scope.dart';
import 'package:sakuramedia/features/rankings/presentation/widgets/rankings_filter_panel.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_fixed_header_layout.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_filter_popover.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_batch_selection.dart';
import 'package:sakuramedia/widgets/domain/rankings/ranking_sort_menu_button.dart';

class DesktopRankingsPage extends ConsumerStatefulWidget {
  const DesktopRankingsPage({super.key});

  @override
  ConsumerState<DesktopRankingsPage> createState() =>
      _DesktopRankingsPageState();
}

class _DesktopRankingsPageState extends ConsumerState<DesktopRankingsPage>
    with
        MultiSelectStateMixin<DesktopRankingsPage, String>,
        MovieBatchSelectionMixin<DesktopRankingsPage>,
        RankingsPageBehaviorMixin<DesktopRankingsPage> {
  static const _scope = RankingSummaryScope.desktop();

  @override
  RankingSummaryScope get rankingScope => _scope;

  @override
  Widget build(BuildContext context) {
    final view = watchRankingsPage();
    final errorBanner = buildRankingFilterErrorBanner(view);

    return AppPageRefreshScope(
      onRefresh: refreshRankings,
      child: AppFixedHeaderLayout(
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selectionMode)
              buildGlassBatchSelectionToolbar()
            else
              _buildHeader(context, view),
            SizedBox(height: context.appSpacing.md),
            if (errorBanner != null) ...[
              errorBanner,
              SizedBox(height: context.appSpacing.md),
            ],
            SizedBox(height: context.appSpacing.sm),
          ],
        ),
        child: AppFilterResultLoadingOverlay(
          isLoading: view.paged.filterUpdate.isLoading,
          hasPreviousItems: view.paged.items.isNotEmpty,
          child: AppPagedLoadMoreScope(
            canLoadMore: () => canAutoLoadMoreRankings,
            onLoadMore: loadMoreRankings,
            child: CustomScrollView(
              key: const PageStorageKey<String>('desktop:rankings:list'),
              controller: rankingsScrollController,
              slivers: [
                SliverMainAxisGroup(
                  key: const Key('desktop-rankings-page'),
                  slivers: buildRankingListSlivers(view),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 与移动榜单页共用同一条顶栏语义：筛选入口（当前榜单）+ 总数 / 更新时间。
  /// 差别只在筛选面板的容器——桌面就地浮层，移动底部抽屉。
  Widget _buildHeader(BuildContext context, RankingsPageView view) {
    final l10n = AppLocalizations.of(context);
    final filters = view.filters;
    final boardLabel = rankingBoardLabel(filters, l10n);
    final syncedAtLabel = rankingSyncedAtLabel(view.syncedAt, l10n);

    return AppGlassListHeader(
      leading: AppGlassFilterPopover(
        panelKey: const Key('rankings-filter-panel'),
        scrollable: true,
        showResetFooter: false,
        enabled: filters.sources.isNotEmpty,
        triggerKey: const Key('desktop-rankings-filter-trigger'),
        label: boardLabel,
        info: <Widget>[
          AppGlassHeaderText(
            key: const Key('desktop-rankings-page-total'),
            label: l10n.sharedMovieCount(view.paged.total),
          ),
          if (syncedAtLabel != null)
            AppGlassHeaderText(
              key: const Key('desktop-rankings-synced-at'),
              label: syncedAtLabel,
            ),
        ],
        panelBuilder: (context) => RankingsFilterPanel(
          filters: filters,
          actions: rankingFilterActions,
        ),
      ),
      trailing: AppGlassHeaderGroup(
        children: <Widget>[
          RankingSortMenuButton(
            triggerKey: const Key('rankings-sort-trigger'),
            panelKey: const Key('rankings-sort-panel'),
            filterState: filters,
            glassGrouped: true,
            onSortChanged: selectRankingSort,
          ),
          if (batchSelectableNumbers.isNotEmpty)
            AppGlassHeaderButton(
              key: Key('$batchKeyPrefix-enter-selection-button'),
              icon: Icons.check_circle_outline,
              label: l10n.baseSelect,
              onTap: enterSelection,
            ),
        ],
      ),
      filterUpdate: view.paged.filterUpdate,
      hasPreviousFilterItems: view.paged.items.isNotEmpty,
      onRetryFilter: retryRankingFilter,
    );
  }
}
