import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/discovery/data/daily_recommendation_movie_dto.dart';
import 'package:sakuramedia/features/discovery/data/hot_actress_release_movie_dto.dart';
import 'package:sakuramedia/features/discovery/data/moment_recommendation_dto.dart';
import 'package:sakuramedia/features/discovery/presentation/moment_recommendation_mapping.dart';
import 'package:sakuramedia/features/discovery/presentation/providers/discovery_preview_providers.dart';
import 'package:sakuramedia/features/discovery/presentation/providers/discovery_preview_state.dart';
import 'package:sakuramedia/features/image_search/presentation/actions/image_search_launcher.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_playback_launcher.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_state.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/domain/media/preview/media_preview_dialog.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_grid.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_image.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_preview_launcher.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_skeleton.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_grid.dart';

class MobileOverviewDiscoverTab extends ConsumerWidget {
  const MobileOverviewDiscoverTab({super.key});

  static const int _dailyPreviewCount = 6;
  static const int _followPreviewCount = 6;
  static const int _hotActressPreviewCount = 6;
  static const int _momentPreviewCount = 4;
  static const int _dailyPageSize = 10;
  static const int _followPageSize = 10;
  static const int _hotActressPageSize = 10;
  static const int _momentPageSize = 10;
  static const _followScope = MovieSummaryScope.subscribedActorsLatest(
    pageSize: _followPageSize,
    initialLoadErrorText: '女优上新加载失败，请稍后重试',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hotActress = ref.watch(
      discoveryHotActressReleasePreviewProvider(_hotActressPageSize),
    );
    final follow = ref.watch(movieSummaryProvider(_followScope));
    final daily = ref.watch(discoveryDailyPreviewProvider(_dailyPageSize));
    final moment = ref.watch(discoveryMomentPreviewProvider(_momentPageSize));

    return AppAdaptiveRefreshScrollView(
      key: const Key('mobile-overview-discover-tab'),
      onRefresh: () => _handleRefresh(ref),
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: context.appSpacing.sm),
              _buildFollowSection(context, ref, follow),
              SizedBox(height: context.appSpacing.lg),
              _buildHotActressSection(context, ref, hotActress),
              SizedBox(height: context.appSpacing.lg),
              _buildDailySection(context, ref, daily),
              SizedBox(height: context.appSpacing.lg),
              _buildMomentSection(context, ref, moment),
              SizedBox(height: context.appSpacing.lg),
            ],
          ),
        ),
      ],
    );
  }

  /// 三个预览独立刷新，单侧失败不影响其余区块。
  Future<void> _handleRefresh(WidgetRef ref) async {
    await Future.wait(<Future<void>>[
      ref
          .read(
            discoveryHotActressReleasePreviewProvider(
              _hotActressPageSize,
            ).notifier,
          )
          .refresh(),
      ref.read(movieSummaryProvider(_followScope).notifier).refresh(),
      ref
          .read(discoveryDailyPreviewProvider(_dailyPageSize).notifier)
          .refresh(),
      ref
          .read(discoveryMomentPreviewProvider(_momentPageSize).notifier)
          .refresh(),
    ]);
  }

  Widget _buildFollowSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<MovieSummaryState> followAsync,
  ) {
    final follow = followAsync.value;
    final paged = follow?.paged;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MobileDiscoverSectionTitle(
          title: '女优上新',
          totalText: '${paged?.total ?? 0} 部',
          actionKey: const Key('mobile-discover-load-more-follow'),
          actionLabel: '更多',
          onActionTap: () => context.push(mobileFollowPath),
        ),
        SizedBox(height: context.appSpacing.md),
        MovieSummaryGrid(
          items: paged?.items.take(_followPreviewCount).toList() ?? const [],
          isLoading: followAsync.isLoading && follow == null,
          errorMessage: followAsync.hasError && follow == null
              ? _followScope.initialLoadErrorText
              : null,
          emptyMessage: '暂无女优上新，先订阅感兴趣的女优，等定时任务同步后展示',
          placeholderCount: _followPreviewCount,
          onMovieTap: (movie) => _openMovieDetail(context, movie.movieNumber),
          onMovieSubscriptionTap: (movie) =>
              _toggleFollowSubscription(ref, movie.movieNumber),
          isMovieSubscriptionUpdating: (movie) =>
              follow?.isSubscriptionUpdating(movie.movieNumber) ?? false,
        ),
      ],
    );
  }

  Future<void> _toggleFollowSubscription(
    WidgetRef ref,
    String movieNumber,
  ) async {
    final result = await ref
        .read(movieSummaryProvider(_followScope).notifier)
        .toggleSubscription(movieNumber);
    showMovieSubscriptionFeedback(result);
  }

  Widget _buildHotActressSection(
    BuildContext context,
    WidgetRef ref,
    DiscoveryPreviewState<HotActressReleaseMovieDto> hotActress,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MobileDiscoverSectionTitle(
          title: '热门新片',
          totalText: '${hotActress.total} 部',
          actionKey: const Key('mobile-discover-load-more-hot-actress'),
          actionLabel: '更多',
          onActionTap: () => context.push(mobileHotActressReleasesPath),
        ),
        SizedBox(height: context.appSpacing.md),
        _buildHotActressBody(context, ref, hotActress),
      ],
    );
  }

  Widget _buildHotActressBody(
    BuildContext context,
    WidgetRef ref,
    DiscoveryPreviewState<HotActressReleaseMovieDto> hotActress,
  ) {
    if (hotActress.errorMessage != null) {
      return _RetryEmptyState(
        message: hotActress.errorMessage!,
        onRetry: () => _handleRefresh(ref),
      );
    }
    final actressNames = <String, String>{
      for (final item in hotActress.items)
        if (item.hotActressName.trim().isNotEmpty)
          item.movie.movieNumber: '热门：${item.hotActressName.trim()}',
    };
    return MovieSummaryGrid(
      items: hotActress.items
          .take(_hotActressPreviewCount)
          .map((item) => item.movie)
          .toList(growable: false),
      isLoading: hotActress.isLoading,
      emptyMessage: '暂无热门新片，待更多影片积累热度后展示',
      placeholderCount: _hotActressPreviewCount,
      secondaryLabelForMovie: (movie) => actressNames[movie.movieNumber],
      useDefaultSubscriptionActions: true,
      onMovieTap: (movie) => _openMovieDetail(context, movie.movieNumber),
    );
  }

  Widget _buildDailySection(
    BuildContext context,
    WidgetRef ref,
    DiscoveryPreviewState<DailyRecommendationMovieDto> daily,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MobileDiscoverSectionTitle(
          title: '今日推荐',
          totalText: '${daily.total} 部',
          actionKey: const Key('mobile-discover-load-more-daily'),
          actionLabel: '更多',
          onActionTap: () => context.push(mobileDiscoverMoviesPath),
        ),
        SizedBox(height: context.appSpacing.md),
        _buildDailyBody(context, ref, daily),
      ],
    );
  }

  Widget _buildDailyBody(
    BuildContext context,
    WidgetRef ref,
    DiscoveryPreviewState<DailyRecommendationMovieDto> daily,
  ) {
    if (daily.errorMessage != null) {
      return _RetryEmptyState(
        message: daily.errorMessage!,
        onRetry: () => _handleRefresh(ref),
      );
    }
    return MovieSummaryGrid(
      items: daily.items
          .take(_dailyPreviewCount)
          .map((item) => item.movie)
          .toList(growable: false),
      isLoading: daily.isLoading,
      emptyMessage: '暂无每日推荐，去搜索看看吧',
      placeholderCount: _dailyPreviewCount,
      onMovieTap: (movie) => _openMovieDetail(context, movie.movieNumber),
    );
  }

  Widget _buildMomentSection(
    BuildContext context,
    WidgetRef ref,
    DiscoveryPreviewState<MomentRecommendationDto> moment,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MobileDiscoverSectionTitle(
          title: '推荐时刻',
          totalText: '${moment.total} 个',
          actionKey: const Key('mobile-discover-load-more-moments'),
          actionLabel: '更多',
          onActionTap: () => context.push(mobileDiscoverMomentsPath),
        ),
        SizedBox(height: context.appSpacing.md),
        _buildMomentBody(context, ref, moment),
      ],
    );
  }

  Widget _buildMomentBody(
    BuildContext context,
    WidgetRef ref,
    DiscoveryPreviewState<MomentRecommendationDto> moment,
  ) {
    if (moment.isLoading) {
      return const AppMobileSkeletonList();
    }
    if (moment.errorMessage != null) {
      return _RetryEmptyState(
        message: moment.errorMessage!,
        onRetry: () => _handleRefresh(ref),
      );
    }
    if (moment.items.isEmpty) {
      return const AppEmptyState(message: '暂无推荐时刻，播放时添加标记，等定时任务处理后展示');
    }
    return MomentGrid(
      items: moment.items
          .take(_momentPreviewCount)
          .map((item) => item.toMomentListItem())
          .toList(growable: false),
      onItemTap: (item) => _openMomentPreview(context, item),
    );
  }

  void _openMovieDetail(BuildContext context, String movieNumber) {
    MobileMovieDetailRouteData(movieNumber: movieNumber).push(context);
  }

  Future<void> _openMomentPreview(
    BuildContext context,
    MomentListItem item,
  ) async {
    final action = await showMomentPreviewOverlay(
      context: context,
      item: item,
      presentation: MediaPreviewPresentation.bottomDrawer,
      drawerKey: const Key('mobile-discover-moment-preview-bottom-sheet'),
    );
    if (!context.mounted || action == null) {
      return;
    }
    switch (action) {
      case MediaPreviewAction.searchSimilar:
        await _searchSimilarFromMoment(context, item);
      case MediaPreviewAction.play:
        final movieNumber = item.movieNumber;
        if (movieNumber == null || movieNumber.isEmpty) {
          return;
        }
        unawaited(
          launchMoviePlayback(
            context,
            movieNumber: movieNumber,
            mediaId: item.mediaId > 0 ? item.mediaId : null,
            positionSeconds: item.offsetSeconds,
          ),
        );
      case MediaPreviewAction.openMovieDetail:
        final movieNumberForDetail = item.movieNumber;
        if (movieNumberForDetail == null || movieNumberForDetail.isEmpty) {
          return;
        }
        MobileMovieDetailRouteData(
          movieNumber: movieNumberForDetail,
        ).push(context);
    }
  }

  Future<void> _searchSimilarFromMoment(
    BuildContext context,
    MomentListItem item,
  ) async {
    final imageUrl = resolveMomentImageUrl(item);
    if (imageUrl.isEmpty) {
      return;
    }
    try {
      await launchImageSearchFromUrl(
        context,
        imageUrl: imageUrl,
        routePath: mobileImageSearchPath,
        fallbackPath: mobileOverviewPath,
        fileName: buildMomentImageFileName(item, imageUrl),
      );
    } catch (_) {
      if (context.mounted) {
        showToast('读取结果图片失败，请稍后重试');
      }
    }
  }
}

class _MobileDiscoverSectionTitle extends StatelessWidget {
  const _MobileDiscoverSectionTitle({
    required this.title,
    required this.totalText,
    this.actionKey,
    this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final String totalText;
  final Key? actionKey;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(width: context.appSpacing.sm),
        Text(
          totalText,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
        const Spacer(),
        if (actionKey != null && actionLabel != null && onActionTap != null)
          AppTextButton(
            key: actionKey,
            label: actionLabel!,
            size: AppTextButtonSize.xSmall,
            trailingIcon: const Icon(Icons.chevron_right_rounded),
            onPressed: onActionTap,
          ),
      ],
    );
  }
}

class _RetryEmptyState extends StatelessWidget {
  const _RetryEmptyState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppEmptyState(message: message),
        SizedBox(height: context.appSpacing.md),
        AppButton(
          key: Key('mobile-discover-retry-${message.hashCode}'),
          label: '重试',
          size: AppButtonSize.small,
          onPressed: () => unawaited(onRetry()),
        ),
      ],
    );
  }
}
