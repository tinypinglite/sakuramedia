import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/features/discovery/data/daily_recommendation_movie_dto.dart';
import 'package:sakuramedia/features/discovery/data/hot_actress_release_movie_dto.dart';
import 'package:sakuramedia/features/discovery/data/moment_recommendation_dto.dart';
import 'package:sakuramedia/features/discovery/presentation/moment_recommendation_mapping.dart';
import 'package:sakuramedia/features/discovery/presentation/providers/discovery_recommendation_feeds_provider.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/features/shared/presentation/hooks/paged_scroll_hook.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_filter_total_header.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/domain/media/preview/media_preview_dialog.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_grid.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_preview_launcher.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_grid.dart';

/// 推荐影片列表共享实现（桌面 / 移动双端壳收敛的 content 层）。
///
/// 平台差异全部收在壳参数里：`pageSize`（移动 18 / 桌面 24）、`keyPrefix`、
/// 顶栏下间距（`headerGap`）、背景色、骨架数、`basePath`（消掉旧的
/// `_movieDetailPath(isMobile:)`）与下拉刷新开关；`basePath` 之下影片详情路径
/// 与本列表自身的分页/刷新/错误态逻辑全部在本层。
class DiscoveryMoviesContent extends StatelessWidget {
  const DiscoveryMoviesContent({
    super.key,
    required this.pageSize,
    required this.keyPrefix,
    required this.headerGap,
    required this.backgroundColor,
    required this.placeholderCount,
    required this.basePath,
    this.enablePullToRefresh = false,
  });

  final int pageSize;
  final String keyPrefix;
  final double headerGap;
  final Color backgroundColor;
  final int placeholderCount;
  final String basePath;
  final bool enablePullToRefresh;

  @override
  Widget build(BuildContext context) {
    final provider = dailyRecommendationFeedProvider(pageSize);
    return _DiscoveryMovieListContent<DailyRecommendationMovieDto>(
      keyPrefix: keyPrefix,
      headerGap: headerGap,
      backgroundColor: backgroundColor,
      placeholderCount: placeholderCount,
      basePath: basePath,
      enablePullToRefresh: enablePullToRefresh,
      initialLoadErrorText: '推荐影片加载失败，请稍后重试',
      loadMoreErrorText: '加载更多推荐影片失败，请点击重试',
      emptyMessage: '暂无推荐影片，去搜索看看吧',
      watch: (ref) => ref.watch(provider),
      loadMore: (ref) => ref.read(provider.notifier).loadMore(),
      reload: (ref) => ref.read(provider.notifier).reload(),
      refresh: (ref) => ref.read(provider.notifier).refresh(),
      movieOf: (item) => item.movie,
    );
  }
}

/// 热门女优新片列表，复用与每日推荐一致的分页和卡片交互。
class HotActressReleasesContent extends StatelessWidget {
  const HotActressReleasesContent({
    super.key,
    required this.pageSize,
    required this.keyPrefix,
    required this.headerGap,
    required this.backgroundColor,
    required this.placeholderCount,
    required this.basePath,
    this.enablePullToRefresh = false,
  });

  final int pageSize;
  final String keyPrefix;
  final double headerGap;
  final Color backgroundColor;
  final int placeholderCount;
  final String basePath;
  final bool enablePullToRefresh;

  @override
  Widget build(BuildContext context) {
    final provider = hotActressReleaseFeedProvider(pageSize);
    return _DiscoveryMovieListContent<HotActressReleaseMovieDto>(
      keyPrefix: keyPrefix,
      headerGap: headerGap,
      backgroundColor: backgroundColor,
      placeholderCount: placeholderCount,
      basePath: basePath,
      enablePullToRefresh: enablePullToRefresh,
      initialLoadErrorText: '热门女优新片加载失败，请稍后重试',
      loadMoreErrorText: '加载更多热门女优新片失败，请点击重试',
      emptyMessage: '暂无热门女优新片，待更多影片积累热度后展示',
      watch: (ref) => ref.watch(provider),
      loadMore: (ref) => ref.read(provider.notifier).loadMore(),
      reload: (ref) => ref.read(provider.notifier).reload(),
      refresh: (ref) => ref.read(provider.notifier).refresh(),
      movieOf: (item) => item.movie,
      useDefaultSubscriptionActions: true,
      secondaryLabelOf: (item) {
        final name = item.hotActressName.trim();
        return name.isEmpty ? null : '热门：$name';
      },
    );
  }
}

class _DiscoveryMovieListContent<T> extends HookConsumerWidget {
  const _DiscoveryMovieListContent({
    required this.keyPrefix,
    required this.headerGap,
    required this.backgroundColor,
    required this.placeholderCount,
    required this.basePath,
    required this.initialLoadErrorText,
    required this.loadMoreErrorText,
    required this.emptyMessage,
    required this.watch,
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
  final Color backgroundColor;
  final int placeholderCount;
  final String basePath;
  final String initialLoadErrorText;
  final String loadMoreErrorText;
  final String emptyMessage;
  final AsyncValue<PagedListState<T>> Function(WidgetRef ref) watch;
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
    final scrollController = usePagedLoadMoreScroll(
      onReachBottom: () {
        // 对齐旧 PagedLoadController:loadMore 失败存续期间滚动不自动重试，
        // 恢复分页的唯一入口是 footer 的重试按钮。
        if (paged.loadMoreErrorMessage == null) {
          unawaited(loadMore(ref));
        }
      },
      triggerOffset: 300,
    );

    final showFooter =
        paged.isNotEmpty &&
        (paged.isLoadingMore || paged.loadMoreErrorMessage != null);
    final sliver = SliverMainAxisGroup(
      key: Key('$keyPrefix-page'),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppFilterTotalHeader(
                leading: const SizedBox.shrink(),
                totalText: '${paged.total} 部',
                totalKey: Key('$keyPrefix-total'),
              ),
              SizedBox(height: headerGap),
            ],
          ),
        ),
        _buildBody(context, ref, async, paged),
        if (showFooter)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: context.appSpacing.md),
              child: AppPagedLoadMoreFooter(
                isLoading: paged.isLoadingMore,
                errorMessage: paged.loadMoreErrorMessage ?? loadMoreErrorText,
                onRetry: () => unawaited(loadMore(ref)),
              ),
            ),
          ),
      ],
    );

    return AppPageRefreshScope(
      onRefresh: () => _handleRefresh(context, ref),
      child: enablePullToRefresh
          ? ColoredBox(
              color: backgroundColor,
              child: AppAdaptiveRefreshScrollView(
                controller: scrollController,
                onRefresh: () => _handleRefresh(context, ref),
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: <Widget>[sliver],
              ),
            )
          : ColoredBox(
              color: backgroundColor,
              child: CustomScrollView(
                controller: scrollController,
                slivers: [sliver],
              ),
            ),
    );
  }

  Future<void> _handleRefresh(BuildContext context, WidgetRef ref) async {
    final errorMessage = await refresh(ref);
    if (errorMessage != null && context.mounted) {
      showToast('刷新失败');
    }
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
    return MovieSummarySliver(
      items: paged.items.map(movieOf).toList(growable: false),
      isLoading: async.isLoading,
      emptyMessage: emptyMessage,
      placeholderCount: placeholderCount,
      secondaryLabelForMovie: secondaryLabels.isEmpty
          ? null
          : (movie) => secondaryLabels[movie.movieNumber],
      useDefaultSubscriptionActions: useDefaultSubscriptionActions,
      onMovieTap: (movie) => _openMovieDetail(context, movie.movieNumber),
      onMovieMenuRequest: (movie, globalPosition) => requestMovieCollectionMenu(
        context,
        movie.movieNumber,
        globalPosition,
        isSubscribed: movie.isSubscribed,
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
/// 平台差异收在壳参数里：`pageSize` / `keyPrefix` / `headerGap` / `backgroundColor` /
/// `basePath` / `previewDrawerKey` / 下拉刷新开关，以及图搜跳转回调
/// `onSearchSimilar`（桌面 launcher / 移动 draft store 中转）。预览弹层统一走
/// [MediaPreviewPresentation.auto]（读 `AppPlatformScope` 分派）。
class DiscoveryMomentsContent extends HookConsumerWidget {
  const DiscoveryMomentsContent({
    super.key,
    required this.pageSize,
    required this.keyPrefix,
    required this.headerGap,
    required this.backgroundColor,
    required this.basePath,
    this.previewDrawerKey,
    this.enablePullToRefresh = false,
    this.onSearchSimilar,
  });

  final int pageSize;
  final String keyPrefix;
  final double headerGap;
  final Color backgroundColor;
  final String basePath;
  final Key? previewDrawerKey;
  final bool enablePullToRefresh;

  /// 图搜导航回调（壳注入：桌面走 launcher / 移动走 draft store 中转）。
  final Future<void> Function(BuildContext context, MomentListItem item)?
  onSearchSimilar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = momentRecommendationFeedProvider(pageSize);
    final async = ref.watch(provider);
    final paged =
        async.value ?? const PagedListState<MomentRecommendationDto>();
    final scrollController = usePagedLoadMoreScroll(
      onReachBottom: () {
        // 同影片页：loadMore 失败存续期间滚动不自动重试。
        if (paged.loadMoreErrorMessage == null) {
          unawaited(ref.read(provider.notifier).loadMore());
        }
      },
      triggerOffset: 300,
    );

    final showFooter =
        paged.isNotEmpty &&
        (paged.isLoadingMore || paged.loadMoreErrorMessage != null);
    final sliver = SliverMainAxisGroup(
      key: Key('$keyPrefix-page'),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppFilterTotalHeader(
                leading: const SizedBox.shrink(),
                totalText: '${paged.total} 个',
                totalKey: Key('$keyPrefix-total'),
              ),
              SizedBox(height: headerGap),
            ],
          ),
        ),
        _buildBody(context, ref, async, paged),
        if (showFooter)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: context.appSpacing.md),
              child: AppPagedLoadMoreFooter(
                isLoading: paged.isLoadingMore,
                errorMessage: paged.loadMoreErrorMessage,
                onRetry: () =>
                    unawaited(ref.read(provider.notifier).loadMore()),
              ),
            ),
          ),
      ],
    );

    return AppPageRefreshScope(
      onRefresh: () => _handleRefresh(context, ref),
      child: enablePullToRefresh
          ? ColoredBox(
              color: backgroundColor,
              child: AppAdaptiveRefreshScrollView(
                controller: scrollController,
                onRefresh: () => _handleRefresh(context, ref),
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: <Widget>[sliver],
              ),
            )
          : ColoredBox(
              color: backgroundColor,
              child: CustomScrollView(
                controller: scrollController,
                slivers: [sliver],
              ),
            ),
    );
  }

  Future<void> _handleRefresh(BuildContext context, WidgetRef ref) async {
    final provider = momentRecommendationFeedProvider(pageSize);
    final errorMessage = await ref.read(provider.notifier).refresh();
    if (errorMessage != null && context.mounted) {
      showToast('刷新失败');
    }
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<PagedListState<MomentRecommendationDto>> async,
    PagedListState<MomentRecommendationDto> paged,
  ) {
    if (async.isLoading) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: context.appLayoutTokens.emptySectionVerticalPadding,
            ),
            child: const CircularProgressIndicator(),
          ),
        ),
      );
    }
    if (async.hasError) {
      final provider = momentRecommendationFeedProvider(pageSize);
      return SliverToBoxAdapter(
        child: DiscoveryRetryEmptyState(
          message: '推荐时刻加载失败，请稍后重试',
          onRetry: () => ref.read(provider.notifier).reload(),
        ),
      );
    }
    if (paged.isEmpty) {
      return const SliverToBoxAdapter(
        child: AppEmptyState(message: '暂无推荐时刻，播放时添加标记，等定时任务处理后展示'),
      );
    }
    return MomentSliver(
      items: paged.items
          .map((item) => item.toMomentListItem())
          .toList(growable: false),
      onItemTap: (item) => _openMomentPreview(context, item),
    );
  }

  Future<void> _openMomentPreview(
    BuildContext context,
    MomentListItem item,
  ) async {
    final action = await showMomentPreviewOverlay(
      context: context,
      item: item,
      presentation: MediaPreviewPresentation.auto,
      drawerKey: previewDrawerKey,
    );
    if (!context.mounted || action == null) {
      return;
    }
    switch (action) {
      case MediaPreviewAction.searchSimilar:
        await _searchSimilarFromMoment(context, item);
      case MediaPreviewAction.play:
        _openPlayerForMoment(context, item);
      case MediaPreviewAction.openMovieDetail:
        _openMovieDetailForMoment(context, item);
    }
  }

  Future<void> _searchSimilarFromMoment(
    BuildContext context,
    MomentListItem item,
  ) async {
    final handler = onSearchSimilar;
    if (handler == null) {
      return;
    }
    await handler(context, item);
  }

  void _openPlayerForMoment(BuildContext context, MomentListItem item) {
    final movieNumber = item.movieNumber;
    if (movieNumber == null || movieNumber.isEmpty) {
      // discovery 推荐时刻仅 JAV，番号必有；视频时刻不会进入此列表。
      return;
    }
    final path = _moviePlayerPath(
      movieNumber,
      mediaId: item.mediaId > 0 ? item.mediaId : null,
      positionSeconds: item.offsetSeconds,
    );
    context.push(path);
  }

  void _openMovieDetailForMoment(BuildContext context, MomentListItem item) {
    final movieNumber = item.movieNumber;
    if (movieNumber == null || movieNumber.isEmpty) {
      return;
    }
    context.push(_movieDetailPath(movieNumber));
  }

  String _movieDetailPath(String movieNumber) {
    final encoded = Uri.encodeComponent(movieNumber);
    return '$basePath/$encoded';
  }

  String _moviePlayerPath(
    String movieNumber, {
    int? mediaId,
    int? positionSeconds,
  }) {
    final encoded = Uri.encodeComponent(movieNumber);
    return Uri(
      path: '$basePath/$encoded/player',
      queryParameters: <String, String>{
        if (mediaId != null) 'mediaId': '$mediaId',
        if (positionSeconds != null) 'positionSeconds': '$positionSeconds',
      },
    ).toString();
  }
}

class DiscoveryRetryEmptyState extends StatelessWidget {
  const DiscoveryRetryEmptyState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppEmptyState(message: message),
        SizedBox(height: context.appSpacing.md),
        AppButton(
          label: '重试',
          size: AppButtonSize.small,
          onPressed: () => unawaited(onRetry()),
        ),
      ],
    );
  }
}
