import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/discovery/data/daily_recommendation_movie_dto.dart';
import 'package:sakuramedia/features/discovery/data/hot_actress_release_movie_dto.dart';
import 'package:sakuramedia/features/discovery/data/moment_recommendation_dto.dart';
import 'package:sakuramedia/features/discovery/presentation/moment_recommendation_mapping.dart';
import 'package:sakuramedia/features/discovery/presentation/pages/shared/discovery_recommendation_content.dart';
import 'package:sakuramedia/features/discovery/presentation/providers/discovery_preview_providers.dart';
import 'package:sakuramedia/features/discovery/presentation/providers/discovery_preview_state.dart';
import 'package:sakuramedia/features/discovery/presentation/providers/taste_profile_provider.dart';
import 'package:sakuramedia/features/discovery/presentation/widgets/taste_profile_section.dart';
import 'package:sakuramedia/features/moments/presentation/actions/moment_preview_flow.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/features/moments/presentation/moment_placeholders.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/movie_placeholders.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_state.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_page_frame.dart';
import 'package:sakuramedia/widgets/base/navigation/app_section_header.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_rail.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_rail.dart';

class DesktopDiscoverPage extends ConsumerStatefulWidget {
  const DesktopDiscoverPage({super.key});

  @override
  ConsumerState<DesktopDiscoverPage> createState() =>
      _DesktopDiscoverPageState();
}

class _DesktopDiscoverPageState extends ConsumerState<DesktopDiscoverPage> {
  // 推荐三腿与关注女优上新均由 provider 驱动；本 State 只保留页面交互与导航职责。
  // 预览 rail 每块只取展示所需的 12 张，溢出内容一律走各自「更多」页；
  // 请求量与展示量一致，不做跨页预热（更多页走独立 feed provider）。
  static const int _previewPageSize = 12;
  static const _followScope = MovieSummaryScope.subscribedActorsLatest(
    pageSize: _previewPageSize,
  );

  MovieCardHoverFeatureActions get _hoverFeatureActions =>
      movieCardHoverFeatureActions(context);

  /// 三个预览独立刷新，单侧失败不影响其余区块。
  Future<void> _refreshDiscovery() async {
    await Future.wait(<Future<void>>[
      ref
          .read(
            discoveryHotActressReleasePreviewProvider(
              _previewPageSize,
            ).notifier,
          )
          .refresh(),
      ref
          .read(discoveryDailyPreviewProvider(_previewPageSize).notifier)
          .refresh(),
      ref
          .read(discoveryMomentPreviewProvider(_previewPageSize).notifier)
          .refresh(),
      ref.read(tasteProfileProvider.notifier).refresh(),
    ]);
  }

  Future<void> _handleRefresh() {
    return Future.wait<void>([
      _refreshDiscovery(),
      ref.read(movieSummaryProvider(_followScope).notifier).refresh(),
    ]);
  }

  Future<void> _toggleFollowSubscription(String movieNumber) async {
    final result = await ref
        .read(movieSummaryProvider(_followScope).notifier)
        .toggleSubscription(movieNumber);
    if (!mounted) return;
    showMovieSubscriptionFeedback(result, l10n: AppLocalizations.of(context));
  }

  @override
  Widget build(BuildContext context) {
    final hotActress = ref.watch(
      discoveryHotActressReleasePreviewProvider(_previewPageSize),
    );
    final daily = ref.watch(discoveryDailyPreviewProvider(_previewPageSize));
    final moment = ref.watch(discoveryMomentPreviewProvider(_previewPageSize));
    final follow = ref.watch(movieSummaryProvider(_followScope));
    return AppPageRefreshScope(
      onRefresh: _handleRefresh,
      child: AppPageFrame(
        title: '',
        child: Column(
          key: const Key('desktop-discover-page'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TasteProfileSection(
              onTagTap: (tagId) => context.pushDesktopTags(tagId: tagId),
              onActorTap: (actorId) => context.pushDesktopActorDetail(
                actorId: actorId,
                fallbackPath: desktopDiscoverPath,
              ),
            ),
            SizedBox(height: context.appSpacing.xl),
            _buildFollowSection(context, follow),
            SizedBox(height: context.appSpacing.xl),
            _buildHotActressSection(context, hotActress),
            SizedBox(height: context.appSpacing.xl),
            _buildDailySection(context, daily),
            SizedBox(height: context.appSpacing.xl),
            _buildMomentSection(context, moment),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowSection(
    BuildContext context,
    AsyncValue<MovieSummaryState> followAsync,
  ) {
    final l10n = AppLocalizations.of(context);
    final follow = followAsync.value;
    final paged = follow?.paged;
    final isLoading = followAsync.isLoading && follow == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: l10n.discoveryActressReleaseTitle,
          trailingText: l10n.sharedMovieCount(paged?.total ?? 0),
          actionKey: const Key('desktop-discover-load-more-follow'),
          actionLabel: l10n.sharedMore,
          onActionTap: () => context.push(desktopFollowPath),
        ),
        SizedBox(height: context.appSpacing.md),
        AppSkeletonizer(
          enabled: isLoading,
          child: MovieSummaryRail(
            items: isLoading
                ? movieListItemPlaceholders(count: _previewPageSize)
                : paged?.items.take(_previewPageSize).toList() ?? const [],
            errorMessage: followAsync.hasError && follow == null
                ? l10n.discoveryActressReleaseLoadFailed
                : null,
            onMovieTap: (movie) => _openMovieDetail(movie.movieNumber),
            onMovieMenuRequest: (movie, globalPosition) =>
                requestMovieCollectionMenu(
                  context,
                  movie.movieNumber,
                  globalPosition,
                  isSubscribed: movie.isSubscribed,
                ),
            onMovieSubscriptionTap: (movie) =>
                _toggleFollowSubscription(movie.movieNumber),
            onMovieToggleCollectionType:
                _hoverFeatureActions.toggleCollectionType,
            onMovieBlacklist: _hoverFeatureActions.blacklist,
            isMovieSubscriptionUpdating: (movie) =>
                follow?.isSubscriptionUpdating(movie.movieNumber) ?? false,
            emptyMessage: l10n.discoveryActressReleaseEmpty,
          ),
        ),
      ],
    );
  }

  Widget _buildHotActressSection(
    BuildContext context,
    DiscoveryPreviewState<HotActressReleaseMovieDto> hotActress,
  ) {
    final l10n = AppLocalizations.of(context);
    final actressNames = <String, String>{
      for (final item in hotActress.items)
        if (item.hotActressName.trim().isNotEmpty)
          item.movie.movieNumber: l10n.discoveryHotActressBadge(
            item.hotActressName.trim(),
          ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: l10n.discoveryHotNewTitle,
          trailingText: l10n.sharedMovieCount(hotActress.total),
          actionKey: const Key('desktop-discover-load-more-hot-actress'),
          actionLabel: l10n.sharedMore,
          onActionTap: () => context.push(desktopHotActressReleasesPath),
        ),
        SizedBox(height: context.appSpacing.md),
        AppSkeletonizer(
          enabled: hotActress.isLoading && hotActress.items.isEmpty,
          child: MovieSummaryRail(
            items: hotActress.isLoading && hotActress.items.isEmpty
                ? movieListItemPlaceholders(count: _previewPageSize)
                : hotActress.items
                      .take(_previewPageSize)
                      .map((item) => item.movie)
                      .toList(growable: false),
            errorMessage: hotActress.errorMessage,
            onMovieTap: (movie) => _openMovieDetail(movie.movieNumber),
            onMovieMenuRequest: (movie, globalPosition) =>
                requestMovieCollectionMenu(
                  context,
                  movie.movieNumber,
                  globalPosition,
                  isSubscribed: movie.isSubscribed,
                ),
            onMovieToggleCollectionType:
                _hoverFeatureActions.toggleCollectionType,
            onMovieBlacklist: _hoverFeatureActions.blacklist,
            secondaryLabelForMovie: (movie) => actressNames[movie.movieNumber],
            useDefaultSubscriptionActions: true,
            emptyMessage: l10n.discoveryHotNewEmpty,
          ),
        ),
      ],
    );
  }

  Widget _buildDailySection(
    BuildContext context,
    DiscoveryPreviewState<DailyRecommendationMovieDto> daily,
  ) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: l10n.discoveryDailyTitle,
          trailingText: l10n.sharedMovieCount(daily.total),
          actionKey: const Key('desktop-discover-load-more-daily'),
          actionLabel: l10n.sharedMore,
          onActionTap: () => context.push(desktopDiscoverMoviesPath),
        ),
        SizedBox(height: context.appSpacing.md),
        _buildDailyBody(context, daily),
      ],
    );
  }

  Widget _buildDailyBody(
    BuildContext context,
    DiscoveryPreviewState<DailyRecommendationMovieDto> daily,
  ) {
    final l10n = AppLocalizations.of(context);
    if (daily.errorMessage != null) {
      return DiscoveryRetryEmptyState(
        message: daily.errorMessage!,
        onRetry: _refreshDiscovery,
        retryKey: Key('desktop-discover-retry-${daily.errorMessage!.hashCode}'),
      );
    }
    final isLoading = daily.isLoading && daily.items.isEmpty;
    return AppSkeletonizer(
      enabled: isLoading,
      child: MovieSummaryRail(
        items: isLoading
            ? movieListItemPlaceholders(count: _previewPageSize)
            : daily.items
                  .take(_previewPageSize)
                  .map((item) => item.movie)
                  .toList(growable: false),
        emptyMessage: l10n.discoveryDailyEmpty,
        onMovieTap: (movie) => _openMovieDetail(movie.movieNumber),
        onMovieMenuRequest: (movie, globalPosition) =>
            requestMovieCollectionMenu(
              context,
              movie.movieNumber,
              globalPosition,
              isSubscribed: movie.isSubscribed,
            ),
        onMovieToggleCollectionType: _hoverFeatureActions.toggleCollectionType,
        onMovieBlacklist: _hoverFeatureActions.blacklist,
      ),
    );
  }

  Widget _buildMomentSection(
    BuildContext context,
    DiscoveryPreviewState<MomentRecommendationDto> moment,
  ) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: l10n.discoveryMomentTitle,
          trailingText: l10n.sharedMomentCount(moment.total),
          actionKey: const Key('desktop-discover-load-more-moments'),
          actionLabel: l10n.sharedMore,
          onActionTap: () => context.push(desktopDiscoverMomentsPath),
        ),
        SizedBox(height: context.appSpacing.md),
        _buildMomentBody(context, moment),
      ],
    );
  }

  Widget _buildMomentBody(
    BuildContext context,
    DiscoveryPreviewState<MomentRecommendationDto> moment,
  ) {
    if (moment.isLoading && moment.items.isEmpty) {
      // loading 用占位时刻渲染真实 rail，由 [AppSkeletonizer] 灰化。
      return AppSkeletonizer(
        enabled: true,
        child: MomentRail(
          items: momentListPlaceholders(count: _previewPageSize),
          onItemTap: _ignoreMomentTap,
        ),
      );
    }
    if (moment.errorMessage != null) {
      return DiscoveryRetryEmptyState(
        message: moment.errorMessage!,
        onRetry: _refreshDiscovery,
        retryKey: Key(
          'desktop-discover-retry-${moment.errorMessage!.hashCode}',
        ),
      );
    }
    if (moment.items.isEmpty) {
      return AppEmptyState(
        message: AppLocalizations.of(context).discoveryMomentEmpty,
      );
    }
    return MomentRail(
      items: moment.items
          .take(_previewPageSize)
          .map((item) => item.toMomentListItem())
          .toList(growable: false),
      onItemTap: _openMomentPreview,
      onItemPlay: _openPlayerForMoment,
      onItemOpenMovie: _openMovieDetailForMoment,
      onItemAddToCollection: _addToCollection,
    );
  }

  void _openMovieDetail(String movieNumber) {
    context.pushDesktopMovieDetail(
      movieNumber: movieNumber,
      fallbackPath: desktopDiscoverPath,
    );
  }

  Future<void> _openMomentPreview(MomentListItem item) {
    return showMomentPreviewFlow(
      context: context,
      item: item,
      fallbackPath: desktopDiscoverPath,
      isRecommendation: true,
    );
  }

  void _openPlayerForMoment(MomentListItem item) {
    unawaited(
      playMomentItem(
        context: context,
        item: item,
        fallbackPath: desktopDiscoverPath,
      ),
    );
  }

  void _openMovieDetailForMoment(MomentListItem item) {
    openMomentSourceMovie(
      context: context,
      item: item,
      fallbackPath: desktopDiscoverPath,
    );
  }

  void _addToCollection(MomentListItem item) {
    unawaited(
      addMomentItemToCollection(context, item: item, isRecommendation: true),
    );
  }
}

void _ignoreMomentTap(MomentListItem _) {}
