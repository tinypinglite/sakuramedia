import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/page_cache_keys.dart';
import 'package:sakuramedia/app/providers/riverpod_page_cache_provider.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/features/movies/presentation/pages/mobile/movie_filter_drawer.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_summary_list_content.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_provider.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_scope.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_sort_menu_button.dart';
import 'package:sakuramedia/widgets/domain/tags/tag_filter_section.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/media_tag_filter_section.dart';

class MobileMoviesPage extends ConsumerStatefulWidget {
  const MobileMoviesPage({super.key});

  @override
  ConsumerState<MobileMoviesPage> createState() => _MobileMoviesPageState();
}

class _MobileMoviesPageState extends ConsumerState<MobileMoviesPage> {
  static const _scope = MovieSummaryScope.movies(
    cacheKey: 'mobile:movies:list',
  );

  /// 影片库的附加标签筛选：选择状态随页面缓存一起保活，避免切页回来后
  /// 「列表按标签过滤、标签面板为空」的不一致；标签数据懒加载。
  static const _tagSelectionScope = TagSelectionScope.custom(
    instanceKey: 'mobile:movies:tags',
    cacheKey: 'mobile:movies:list',
    preload: false,
  );

  late final RiverpodPageHandle _pageCacheHandle;

  /// 供移动筛选抽屉的 footer 实时反映「标签条件是否生效」。
  final ValueNotifier<bool> _tagSelectionActive = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _pageCacheHandle = ref
        .read(riverpodPageCacheProvider)
        .obtain(
          key: mobileMoviesPageCacheKey(),
          resolveLinks: () {
            final movieLink = ref
                .read(movieSummaryProvider(_scope).notifier)
                .cacheLink;
            final tagLink = ref
                .read(tagSelectionProvider(_tagSelectionScope).notifier)
                .cacheLink;
            return [?movieLink, ?tagLink];
          },
        );
  }

  @override
  void dispose() {
    _tagSelectionActive.dispose();
    _pageCacheHandle.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tagSelectionProvider(_tagSelectionScope), (_, next) {
      _tagSelectionActive.value = next.hasSelection;
    });
    return MovieSummaryListContent(
      scope: _scope,
      surfaceColor: context.appColors.surfaceCard,
      contentKey: const Key('mobile-movies-page'),
      totalKey: const Key('mobile-movies-page-total'),
      tagSelectionScope: _tagSelectionScope,
      sectionSpacing: context.appSpacing.md,
      onMovieTap: (context, movieNumber) =>
          MobileMovieDetailRouteData(movieNumber: movieNumber).push(context),
      headerBuilder: _buildMobileHeader,
      useMobileSelectionLayout: true,
      bodyBuilder: (context, scrollController, sliver, onRefresh) =>
          AppAdaptiveRefreshScrollView(
            key: const PageStorageKey<String>('mobile:movies:list'),
            onRefresh: onRefresh!,
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[sliver],
          ),
      enableRefresh: true,
      onRefreshFailure: (context) =>
          showToast(AppLocalizations.of(context).moviePageRefreshFailed),
    );
  }

  Widget _buildMobileHeader(
    BuildContext context,
    MovieSummaryListHeaderArgs args,
  ) {
    final l10n = AppLocalizations.of(context);
    return AppListHeader(
      filterButtonKey: const Key('mobile-movies-filter-button'),
      filterTooltip: l10n.moviePageFilterTooltip,
      filterLabel: _filterLabel(l10n, args),
      onFilterTap: () => _openFilterDrawer(context, args),
      informationSlots: [
        AppListHeaderInfo(
          key: const Key('mobile-movies-total'),
          label: l10n.moviePageMovieCount(args.total),
        ),
      ],
      actionSlots: [
        MovieSortMenuButton(
          triggerKey: const Key('mobile-movies-sort-trigger'),
          drawerKey: const Key('mobile-movies-sort-drawer'),
          filterState: args.filterState,
          onChanged: args.onApply,
          useDrawer: true,
        ),
      ],
    );
  }

  Future<void> _openFilterDrawer(
    BuildContext context,
    MovieSummaryListHeaderArgs args,
  ) async {
    // 抽屉内容是打开那一刻的快照，且页面缓存恢复时 listener 不会补发；
    // 打开前显式同步一次标签生效状态，避免 footer 初始判断错误。
    _tagSelectionActive.value = ref
        .read(tagSelectionProvider(_tagSelectionScope))
        .hasSelection;
    await showMobileMovieFilterDrawer(
      context,
      current: args.filterState,
      onChanged: args.onApply,
      tagSection: TagFilterSection(scope: _tagSelectionScope),
      // 分节必须挂在抽屉自己的本地筛选状态上：抽屉其它分节改状态时基于
      // `local.copyWith(...)` 重建，若媒体标签仍用打开抽屉时的快照，
      // 两边的条件会互相覆盖。
      mediaTagSectionBuilder: (context, local, onApply) => MediaTagFilterSection(
        selectedTagIds: local.mediaTagIds,
        matchMode: local.mediaTagMatch,
        onChanged: (tagIds, matchMode) => onApply(
          local.copyWith(
            mediaTagIds: tagIds,
            mediaTagMatch: matchMode,
          ),
        ),
      ),
      extraActive: _tagSelectionActive,
      onResetExtra: () {
        ref.read(tagSelectionProvider(_tagSelectionScope).notifier).clear();
      },
    );
  }

  String _filterLabel(AppLocalizations l10n, MovieSummaryListHeaderArgs args) {
    return movieFilterSummaryLabel(
      l10n: l10n,
      filter: args.filterState,
      tagSelection: args.tagSelection,
    );
  }
}
