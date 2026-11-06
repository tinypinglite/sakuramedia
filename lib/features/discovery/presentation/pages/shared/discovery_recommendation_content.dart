import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_fixed_header_layout.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/features/discovery/data/daily_recommendation_movie_dto.dart';
import 'package:sakuramedia/features/discovery/data/hot_actress_release_movie_dto.dart';
import 'package:sakuramedia/features/discovery/data/moment_recommendation_dto.dart';
import 'package:sakuramedia/features/discovery/presentation/moment_recommendation_mapping.dart';
import 'package:sakuramedia/features/discovery/presentation/providers/discovery_recommendation_feeds_provider.dart';
import 'package:sakuramedia/features/moments/presentation/actions/moment_preview_flow.dart';
import 'package:sakuramedia/features/moments/presentation/moment_placeholders.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/movie_placeholders.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_error_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_error_banner.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_grid.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_grid.dart';

/// 推荐影片列表共享实现（桌面 / 移动双端壳收敛的 content 层）。
///
/// 平台差异全部收在壳参数里：`pageSize`（移动 18 / 桌面 24）、`keyPrefix`、
/// 顶栏下间距（`headerGap`）、骨架数、`basePath`（消掉旧的
/// `_movieDetailPath(isMobile:)`）与下拉刷新开关；`basePath` 之下影片详情路径
/// 与本列表自身的分页/刷新/错误态逻辑全部在本层。
class DiscoveryMoviesContent extends StatelessWidget {
  const DiscoveryMoviesContent({
    super.key,
    required this.pageSize,
    required this.keyPrefix,
    required this.headerGap,
    required this.placeholderCount,
    required this.basePath,
    this.enablePullToRefresh = false,
  });

  final int pageSize;
  final String keyPrefix;
  final double headerGap;
  final int placeholderCount;
  final String basePath;
  final bool enablePullToRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = dailyRecommendationFeedProvider(pageSize);
    return _DiscoveryMovieListContent<DailyRecommendationMovieDto>(
      keyPrefix: keyPrefix,
      headerGap: headerGap,
      placeholderCount: placeholderCount,
      basePath: basePath,
      enablePullToRefresh: enablePullToRefresh,
      initialLoadErrorText: l10n.errorRecommendedMovieLoadFailed,
      loadMoreErrorText: l10n.errorLoadMoreRecommendedMoviesFailed,
      emptyMessage: l10n.discoveryRecommendedEmpty,
      // 中立化 loadMore 状态：翻页 loading/失败只重建独立页脚，不重建网格。
      watch: (ref) => ref.watch(
        provider.select(
          (asyncValue) => asyncValue.whenData(withoutLoadMoreStatus),
        ),
      ),
      loadMore: (ref) => ref.read(provider.notifier).loadMore(),
      reload: (ref) => ref.read(provider.notifier).reload(),
      refresh: (ref) => ref.read(provider.notifier).refresh(),
      movieOf: (item) => item.movie,
      watchLoadMoreFooter: (ref) => ref.watch(
        provider.select((asyncState) {
          final paged = asyncState.value;
          if (paged == null || paged.isEmpty) {
            return (isLoading: false, errorMessage: null, hasItems: false);
          }
          return (
            isLoading: paged.isLoadingMore,
            errorMessage: paged.loadMoreErrorMessage,
            hasItems: true,
          );
        }),
      ),
      canLoadMore: (ref) => ref.read(provider).value?.canAutoLoadMore ?? false,
    );
  }
}

/// 热门新片列表，复用与每日推荐一致的分页和卡片交互。
class HotActressReleasesContent extends StatelessWidget {
  const HotActressReleasesContent({
    super.key,
    required this.pageSize,
    required this.keyPrefix,
    required this.headerGap,
    required this.placeholderCount,
    required this.basePath,
    this.enablePullToRefresh = false,
  });

  final int pageSize;
  final String keyPrefix;
  final double headerGap;
  final int placeholderCount;
  final String basePath;
  final bool enablePullToRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = hotActressReleaseFeedProvider(pageSize);
    return _DiscoveryMovieListContent<HotActressReleaseMovieDto>(
      keyPrefix: keyPrefix,
      headerGap: headerGap,
      placeholderCount: placeholderCount,
      basePath: basePath,
      enablePullToRefresh: enablePullToRefresh,
      initialLoadErrorText: l10n.errorHotNewMovieLoadFailed,
      loadMoreErrorText: l10n.errorLoadMoreHotNewMoviesFailed,
      emptyMessage: l10n.discoveryHotNewEmpty,
      // 中立化 loadMore 状态：翻页 loading/失败只重建独立页脚，不重建网格。
      watch: (ref) => ref.watch(
        provider.select(
          (asyncValue) => asyncValue.whenData(withoutLoadMoreStatus),
        ),
      ),
      loadMore: (ref) => ref.read(provider.notifier).loadMore(),
      reload: (ref) => ref.read(provider.notifier).reload(),
      refresh: (ref) => ref.read(provider.notifier).refresh(),
      movieOf: (item) => item.movie,
      watchLoadMoreFooter: (ref) => ref.watch(
        provider.select((asyncState) {
          final paged = asyncState.value;
          if (paged == null || paged.isEmpty) {
            return (isLoading: false, errorMessage: null, hasItems: false);
          }
          return (
            isLoading: paged.isLoadingMore,
            errorMessage: paged.loadMoreErrorMessage,
            hasItems: true,
          );
        }),
      ),
      canLoadMore: (ref) => ref.read(provider).value?.canAutoLoadMore ?? false,
      useDefaultSubscriptionActions: true,
      secondaryLabelOf: (item) {
        final name = item.hotActressName.trim();
        return name.isEmpty ? null : l10n.discoveryHotActressBadge(name);
      },
    );
  }
}

class _DiscoveryMovieListContent<T> extends HookConsumerWidget {
  const _DiscoveryMovieListContent({
    required this.keyPrefix,
    required this.headerGap,
    required this.placeholderCount,
    required this.basePath,
    required this.initialLoadErrorText,
    required this.loadMoreErrorText,
    required this.emptyMessage,
    required this.watch,
    required this.watchLoadMoreFooter,
    required this.canLoadMore,
    required this.loadMore,
    required this.reload,
    required this.refresh,
    required this.movieOf,
    this.enablePullToRefresh = false,
    this.useDefaultSubscriptionActions = false,
    this.secondaryLabelOf,
  });

  final String keyPrefix;
  final double headerGap;
  final int placeholderCount;
  final String basePath;
  final String initialLoadErrorText;
  final String loadMoreErrorText;
  final String emptyMessage;
  final AsyncValue<PagedListState<T>> Function(WidgetRef ref) watch;

  /// loadMore 状态的窄订阅：页脚用它 watch，只在 loading/失败/条目空否变化时重建。
  final ({bool isLoading, String? errorMessage, bool hasItems}) Function(
    WidgetRef ref,
  )
  watchLoadMoreFooter;

  /// 读实时分页状态，判断当前是否允许自动请求下一页。
  final bool Function(WidgetRef ref) canLoadMore;
  final Future<void> Function(WidgetRef ref) loadMore;
  final Future<void> Function(WidgetRef ref) reload;
  final Future<String?> Function(WidgetRef ref) refresh;
  final MovieListItemDto Function(T item) movieOf;
  final bool useDefaultSubscriptionActions;
  final String? Function(T item)? secondaryLabelOf;
  final bool enablePullToRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = watch(ref);
    final paged = async.value ?? PagedListState<T>();
    final scrollController = useScrollController();
    final refreshError = useState<String?>(null);

    Future<void> handleRefresh() async {
      final errorMessage = await refresh(ref);
      if (context.mounted) {
        refreshError.value = errorMessage;
      }
    }

    final sliver = SliverMainAxisGroup(
      key: Key('$keyPrefix-page'),
      slivers: [
        _buildBody(context, ref, async, paged),
        // loadMore 页脚独立订阅：翻页状态翻转只重建它，不重建上面网格。
        PagedLoadMoreFooterSliver(
          watchFooter: (ref) {
            final footer = watchLoadMoreFooter(ref);
            if (!footer.hasItems) {
              return null;
            }
            return (
              isLoading: footer.isLoading,
              errorMessage: footer.errorMessage ?? loadMoreErrorText,
            );
          },
          onLoadMore: (ref) => unawaited(loadMore(ref)),
        ),
      ],
    );

    return AppFixedHeaderLayout(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: headerGap),
          if (refreshError.value case final message?)
            Padding(
              padding: EdgeInsets.only(bottom: context.appSpacing.sm),
              child: AppInlineErrorBanner(
                key: Key('$keyPrefix-refresh-error'),
                message: message,
                retryKey: Key('$keyPrefix-refresh-retry'),
                onRetry: handleRefresh,
              ),
            ),
        ],
      ),
      child: AppPageRefreshScope(
        onRefresh: handleRefresh,
        child: AppPagedLoadMoreScope(
          canLoadMore: () => canLoadMore(ref),
          onLoadMore: () => loadMore(ref),
          child: enablePullToRefresh
              ? AppAdaptiveRefreshScrollView(
                  controller: scrollController,
                  onRefresh: handleRefresh,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: <Widget>[sliver],
                )
              : CustomScrollView(
                  controller: scrollController,
                  slivers: [sliver],
                ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<PagedListState<T>> async,
    PagedListState<T> paged,
  ) {
    if (async.hasError) {
      return SliverToBoxAdapter(
        child: DiscoveryRetryEmptyState(
          message: initialLoadErrorText,
          onRetry: () => reload(ref),
        ),
      );
    }
    final secondaryLabels = <String, String>{};
    for (final item in paged.items) {
      final label = secondaryLabelOf?.call(item)?.trim();
      if (label != null && label.isNotEmpty) {
        secondaryLabels[movieOf(item).movieNumber] = label;
      }
    }
    final isLoading = async.isLoading && async.value == null;
    final hoverActions = movieCardHoverFeatureActions(context);
    return AppSkeletonizer.sliver(
      enabled: isLoading,
      child: MovieSummarySliver(
        items: isLoading
            ? movieListItemPlaceholders(count: placeholderCount)
            : paged.items.map(movieOf).toList(growable: false),
        emptyMessage: emptyMessage,
        secondaryLabelForMovie: secondaryLabels.isEmpty
            ? null
            : (movie) => secondaryLabels[movie.movieNumber],
        useDefaultSubscriptionActions: useDefaultSubscriptionActions,
        onMovieTap: (movie) => _openMovieDetail(context, movie.movieNumber),
        onMovieMenuRequest: (movie, globalPosition) =>
            requestMovieCollectionMenu(
              context,
              movie.movieNumber,
              globalPosition,
              isSubscribed: movie.isSubscribed,
            ),
        onMovieToggleCollectionType: hoverActions.toggleCollectionType,
        onMovieBlacklist: hoverActions.blacklist,
      ),
    );
  }

  void _openMovieDetail(BuildContext context, String movieNumber) {
    context.push(_movieDetailPath(movieNumber));
  }

  String _movieDetailPath(String movieNumber) {
    final encoded = Uri.encodeComponent(movieNumber);
    return '$basePath/$encoded';
  }
}

/// 推荐时刻列表共享实现（桌面 / 移动双端壳收敛的 content 层）。
///
/// 平台差异收在壳参数里：`pageSize` / `keyPrefix` / `headerGap` /
/// `fallbackPath` / `previewDrawerKey` / 下拉刷新开关。预览与悬停动作统一走
/// [showMomentPreviewFlow] 的推荐模式（推荐 ID 不当真实时刻 ID 用）。
class DiscoveryMomentsContent extends HookConsumerWidget {
  const DiscoveryMomentsContent({
    super.key,
    required this.pageSize,
    required this.keyPrefix,
    required this.headerGap,
    required this.fallbackPath,
    this.previewDrawerKey,
    this.enablePullToRefresh = false,
  });

  final int pageSize;
  final String keyPrefix;
  final double headerGap;

  /// 预览关闭后的图搜 / 播放 / 影片详情 / 演员详情兜底路径。
  final String fallbackPath;

  final Key? previewDrawerKey;
  final bool enablePullToRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = momentRecommendationFeedProvider(pageSize);
    // 中立化 loadMore 状态：翻页 loading/失败只重建独立页脚，不重建网格。
    final async = ref.watch(
      provider.select(
        (asyncValue) => asyncValue.whenData(withoutLoadMoreStatus),
      ),
    );
    final paged =
        async.value ?? const PagedListState<MomentRecommendationDto>();
    final scrollController = useScrollController();
    final refreshError = useState<String?>(null);

    Future<void> handleRefresh() async {
      final provider = momentRecommendationFeedProvider(pageSize);
      final errorMessage = await ref.read(provider.notifier).refresh();
      if (context.mounted) {
        refreshError.value = errorMessage;
      }
    }

    final sliver = SliverMainAxisGroup(
      key: Key('$keyPrefix-page'),
      slivers: [
        _buildBody(context, ref, async, paged),
        // loadMore 页脚独立订阅：翻页状态翻转只重建它，不重建上面网格。
        PagedLoadMoreFooterSliver(
          watchFooter: (ref) => ref.watch(
            provider.select((s) {
              final moments = s.value;
              if (moments == null || moments.isEmpty) {
                return null;
              }
              return (
                isLoading: moments.isLoadingMore,
                errorMessage: moments.loadMoreErrorMessage,
              );
            }),
          ),
          onLoadMore: (ref) =>
              unawaited(ref.read(provider.notifier).loadMore()),
        ),
      ],
    );

    return AppFixedHeaderLayout(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: headerGap),
          if (refreshError.value case final message?)
            Padding(
              padding: EdgeInsets.only(bottom: context.appSpacing.sm),
              child: AppInlineErrorBanner(
                key: Key('$keyPrefix-refresh-error'),
                message: message,
                retryKey: Key('$keyPrefix-refresh-retry'),
                onRetry: handleRefresh,
              ),
            ),
        ],
      ),
      child: AppPageRefreshScope(
        onRefresh: handleRefresh,
        child: AppPagedLoadMoreScope(
          canLoadMore: () => ref.read(provider).value?.canAutoLoadMore ?? false,
          onLoadMore: () => ref.read(provider.notifier).loadMore(),
          child: enablePullToRefresh
              ? AppAdaptiveRefreshScrollView(
                  controller: scrollController,
                  onRefresh: handleRefresh,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: <Widget>[sliver],
                )
              : CustomScrollView(
                  controller: scrollController,
                  slivers: [sliver],
                ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<PagedListState<MomentRecommendationDto>> async,
    PagedListState<MomentRecommendationDto> paged,
  ) {
    if (async.isLoading && async.value == null) {
      // loading 用占位时刻渲染真实网格，由 [AppSkeletonizer] 灰化。
      return AppSkeletonizer.sliver(
        enabled: true,
        child: MomentSliver(
          items: momentListPlaceholders(count: pageSize),
          onItemTap: _ignoreMomentTap,
        ),
      );
    }
    if (async.hasError) {
      final provider = momentRecommendationFeedProvider(pageSize);
      return SliverToBoxAdapter(
        child: DiscoveryRetryEmptyState(
          message: AppLocalizations.of(
            context,
          ).errorRecommendedMomentLoadFailed,
          onRetry: () => ref.read(provider.notifier).reload(),
        ),
      );
    }
    if (paged.isEmpty) {
      return SliverToBoxAdapter(
        child: AppEmptyState(
          message: AppLocalizations.of(context).discoveryMomentEmpty,
        ),
      );
    }
    return MomentSliver(
      items: paged.items
          .map((item) => item.toMomentListItem())
          .toList(growable: false),
      onItemTap: (item) => _openMomentPreview(context, item),
      onItemPlay: (item) => unawaited(
        playMomentItem(
          context: context,
          item: item,
          fallbackPath: fallbackPath,
        ),
      ),
      onItemOpenMovie: (item) => openMomentSourceMovie(
        context: context,
        item: item,
        fallbackPath: fallbackPath,
      ),
      onItemAddToCollection: (item) => unawaited(
        addMomentItemToCollection(context, item: item, isRecommendation: true),
      ),
    );
  }

  Future<void> _openMomentPreview(BuildContext context, MomentListItem item) {
    return showMomentPreviewFlow(
      context: context,
      item: item,
      fallbackPath: fallbackPath,
      drawerKey: previewDrawerKey,
      isRecommendation: true,
    );
  }
}

void _ignoreMomentTap(MomentListItem _) {}

class DiscoveryRetryEmptyState extends StatelessWidget {
  const DiscoveryRetryEmptyState({
    super.key,
    required this.message,
    required this.onRetry,
    this.retryKey,
  });

  final String message;
  final Future<void> Function() onRetry;
  final Key? retryKey;

  @override
  Widget build(BuildContext context) {
    return AppErrorState(
      title: AppLocalizations.of(context).baseActionFailed,
      message: message,
      retryKey: retryKey,
      onRetry: () => unawaited(onRetry()),
      variant: AppStatePanelVariant.section,
    );
  }
}
