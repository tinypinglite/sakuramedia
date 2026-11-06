import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/discovery/data/hot_actress_release_movie_dto.dart';
import 'package:sakuramedia/features/discovery/data/moment_recommendation_dto.dart';
import 'package:sakuramedia/features/discovery/presentation/moment_recommendation_mapping.dart';
import 'package:sakuramedia/features/discovery/presentation/pages/shared/discovery_recommendation_content.dart';
import 'package:sakuramedia/features/discovery/presentation/providers/discovery_recommendation_feeds_provider.dart';
import 'package:sakuramedia/features/discovery/presentation/providers/taste_profile_provider.dart';
import 'package:sakuramedia/features/discovery/presentation/widgets/taste_profile_section.dart';
import 'package:sakuramedia/features/moments/presentation/actions/moment_preview_flow.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/features/moments/presentation/moment_placeholders.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/movie_placeholders.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/navigation/app_section_header.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_rail.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_rail.dart';

/// 发现首页共享内容：移动 tab 与桌面独立页只在壳和路由上不同。
class DiscoveryOverviewContent extends ConsumerWidget {
  const DiscoveryOverviewContent({
    super.key,
    required this.mobile,
    required this.previewSize,
  });

  final bool mobile;
  final int previewSize;

  String get _keyPrefix => mobile ? 'mobile' : 'desktop';

  String get _fallbackPath => mobile ? mobileOverviewPath : desktopDiscoverPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final followScope = MovieSummaryScope.subscribedActorsLatest(
      pageSize: previewSize,
    );
    final follow = ref.watch(movieSummaryProvider(followScope));
    final hot = ref.watch(hotActressReleaseFeedProvider(previewSize));
    final daily = ref.watch(dailyRecommendationFeedProvider(previewSize));
    final moment = ref.watch(momentRecommendationFeedProvider(previewSize));
    final followPaged = follow.value?.paged;
    final hotPaged = hot.value;
    final dailyPaged = daily.value;
    final momentPaged = moment.value;
    final hoverActions = mobile ? null : movieCardHoverFeatureActions(context);
    final actionSize = mobile
        ? AppTextButtonSize.xSmall
        : AppTextButtonSize.small;
    final sectionGap = mobile ? context.appSpacing.lg : context.appSpacing.xl;
    final hotLabels = <String, String>{
      for (final item in hotPaged?.items ?? const <HotActressReleaseMovieDto>[])
        if (item.hotActressName.trim().isNotEmpty)
          item.movie.movieNumber: l10n.discoveryHotActressBadge(
            item.hotActressName.trim(),
          ),
    };

    final content = Column(
      key: mobile ? null : const Key('desktop-discover-page'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mobile) SizedBox(height: context.appSpacing.sm),
        TasteProfileSection(
          onTagTap: (tagId) => _openTag(context, tagId),
          onActorTap: (actorId) => _openActor(context, actorId),
        ),
        SizedBox(height: sectionGap),
        _DiscoveryMovieRailSection(
          title: l10n.discoveryActressReleaseTitle,
          actionKey: Key('$_keyPrefix-discover-load-more-follow'),
          actionSize: actionSize,
          onMore: () =>
              context.push(mobile ? mobileFollowPath : desktopFollowPath),
          total: followPaged?.total ?? 0,
          isLoading: follow.isLoading && follow.value == null,
          items:
              followPaged?.items.take(previewSize).toList(growable: false) ??
              const <MovieListItemDto>[],
          errorMessage: follow.hasError && follow.value == null
              ? l10n.discoveryActressReleaseLoadFailed
              : null,
          emptyMessage: l10n.discoveryActressReleaseEmpty,
          retryKey: Key('$_keyPrefix-discover-retry-follow'),
          onRetry: () =>
              ref.read(movieSummaryProvider(followScope).notifier).reload(),
          onMovieTap: (movie) => _openMovieDetail(context, movie.movieNumber),
          onMovieMenuRequest: (movie, globalPosition) =>
              requestMovieCollectionMenu(
                context,
                movie.movieNumber,
                globalPosition,
                isSubscribed: movie.isSubscribed,
              ),
          onMovieSubscriptionTap: (movie) => _toggleFollowSubscription(
            context,
            ref,
            followScope,
            movie.movieNumber,
          ),
          isMovieSubscriptionUpdating: (movie) =>
              follow.value?.isSubscriptionUpdating(movie.movieNumber) ?? false,
          hoverActions: hoverActions,
          placeholderCount: previewSize,
        ),
        SizedBox(height: sectionGap),
        _DiscoveryMovieRailSection(
          title: l10n.discoveryHotNewTitle,
          actionKey: Key('$_keyPrefix-discover-load-more-hot-actress'),
          actionSize: actionSize,
          onMore: () => context.push(
            mobile
                ? mobileHotActressReleasesPath
                : desktopHotActressReleasesPath,
          ),
          total: hotPaged?.total ?? 0,
          isLoading: hot.isLoading && hot.value == null,
          items:
              hotPaged?.items
                  .take(previewSize)
                  .map((item) => item.movie)
                  .toList(growable: false) ??
              const <MovieListItemDto>[],
          errorMessage: hot.hasError && hot.value == null
              ? l10n.errorHotNewMovieLoadFailed
              : null,
          emptyMessage: l10n.discoveryHotNewEmpty,
          retryKey: Key('$_keyPrefix-discover-retry-hot-actress'),
          onRetry: () => ref
              .read(hotActressReleaseFeedProvider(previewSize).notifier)
              .reload(),
          onMovieTap: (movie) => _openMovieDetail(context, movie.movieNumber),
          onMovieMenuRequest: (movie, globalPosition) =>
              requestMovieCollectionMenu(
                context,
                movie.movieNumber,
                globalPosition,
                isSubscribed: movie.isSubscribed,
              ),
          secondaryLabelForMovie: hotLabels.isEmpty
              ? null
              : (movie) => hotLabels[movie.movieNumber],
          useDefaultSubscriptionActions: true,
          hoverActions: hoverActions,
          placeholderCount: previewSize,
        ),
        SizedBox(height: sectionGap),
        _DiscoveryMovieRailSection(
          title: l10n.discoveryDailyTitle,
          actionKey: Key('$_keyPrefix-discover-load-more-daily'),
          actionSize: actionSize,
          onMore: () => context.push(
            mobile ? mobileDiscoverMoviesPath : desktopDiscoverMoviesPath,
          ),
          total: dailyPaged?.total ?? 0,
          isLoading: daily.isLoading && daily.value == null,
          items:
              dailyPaged?.items
                  .take(previewSize)
                  .map((item) => item.movie)
                  .toList(growable: false) ??
              const <MovieListItemDto>[],
          errorMessage: daily.hasError && daily.value == null
              ? l10n.discoveryDailyLoadFailed
              : null,
          emptyMessage: l10n.discoveryDailyEmpty,
          retryKey: Key('$_keyPrefix-discover-retry-daily'),
          onRetry: () => ref
              .read(dailyRecommendationFeedProvider(previewSize).notifier)
              .reload(),
          onMovieTap: (movie) => _openMovieDetail(context, movie.movieNumber),
          onMovieMenuRequest: (movie, globalPosition) =>
              requestMovieCollectionMenu(
                context,
                movie.movieNumber,
                globalPosition,
                isSubscribed: movie.isSubscribed,
              ),
          hoverActions: hoverActions,
          placeholderCount: previewSize,
        ),
        SizedBox(height: sectionGap),
        _DiscoveryMomentSection(
          actionKey: Key('$_keyPrefix-discover-load-more-moments'),
          actionSize: actionSize,
          onMore: () => context.push(
            mobile ? mobileDiscoverMomentsPath : desktopDiscoverMomentsPath,
          ),
          total: momentPaged?.total ?? 0,
          isLoading: moment.isLoading && moment.value == null,
          items: momentPaged?.items ?? const <MomentRecommendationDto>[],
          errorMessage: moment.hasError && moment.value == null
              ? l10n.errorRecommendedMomentLoadFailed
              : null,
          emptyMessage: l10n.discoveryMomentEmpty,
          retryKey: Key('$_keyPrefix-discover-retry-moments'),
          onRetry: () => ref
              .read(momentRecommendationFeedProvider(previewSize).notifier)
              .reload(),
          previewSize: previewSize,
          onItemTap: (item) => _openMomentPreview(context, item),
          onItemPlay: (item) => _openMomentPlayer(context, item),
          onItemOpenMovie: (item) => _openMomentMovie(context, item),
          onItemAddToCollection: (item) =>
              _addMomentToCollection(context, item),
        ),
        if (mobile) SizedBox(height: context.appSpacing.lg),
      ],
    );

    if (mobile) {
      return AppAdaptiveRefreshScrollView(
        key: const Key('mobile-overview-discover-tab'),
        onRefresh: () => _handleRefresh(context, ref, followScope),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[SliverToBoxAdapter(child: content)],
      );
    }

    return AppPageRefreshScope(
      onRefresh: () => _handleRefresh(context, ref, followScope),
      child: SingleChildScrollView(child: content),
    );
  }

  Future<void> _handleRefresh(
    BuildContext context,
    WidgetRef ref,
    MovieSummaryScope followScope,
  ) async {
    var failed = false;
    try {
      final errors = await Future.wait<String?>([
        ref.read(movieSummaryProvider(followScope).notifier).refresh(),
        ref.read(hotActressReleaseFeedProvider(previewSize).notifier).refresh(),
        ref
            .read(dailyRecommendationFeedProvider(previewSize).notifier)
            .refresh(),
        ref
            .read(momentRecommendationFeedProvider(previewSize).notifier)
            .refresh(),
        ref.read(tasteProfileProvider.notifier).refresh(),
      ]);
      failed = errors.any((error) => error != null);
    } catch (_) {
      failed = true;
    }
    if (!context.mounted || !failed) {
      return;
    }
    showToast(
      AppLocalizations.of(context).sharedRefreshFailed,
      tone: AppToastTone.error,
    );
  }

  void _openTag(BuildContext context, int tagId) {
    if (mobile) {
      MobileRoutes.tagMovies(tagId: tagId).push(context);
      return;
    }
    DesktopRoutes.tagMovies(tagId: tagId).push(context);
  }

  void _openActor(BuildContext context, int actorId) {
    if (mobile) {
      MobileRoutes.actorDetail(actorId: actorId).push(context);
      return;
    }
    DesktopRoutes.actorDetail(
      actorId: actorId,
      fallbackPath: desktopDiscoverPath,
    ).push(context);
  }

  void _openMovieDetail(BuildContext context, String movieNumber) {
    if (mobile) {
      MobileRoutes.movieDetail(movieNumber: movieNumber).push(context);
      return;
    }
    DesktopRoutes.movieDetail(
      movieNumber: movieNumber,
      fallbackPath: desktopDiscoverPath,
    ).push(context);
  }

  Future<void> _toggleFollowSubscription(
    BuildContext context,
    WidgetRef ref,
    MovieSummaryScope scope,
    String movieNumber,
  ) async {
    final result = await ref
        .read(movieSummaryProvider(scope).notifier)
        .toggleSubscription(movieNumber);
    if (!context.mounted) return;
    showMovieSubscriptionFeedback(result, l10n: AppLocalizations.of(context));
  }

  Future<void> _openMomentPreview(BuildContext context, MomentListItem item) {
    return showMomentPreviewFlow(
      context: context,
      item: item,
      fallbackPath: _fallbackPath,
      drawerKey: mobile
          ? const Key('mobile-discover-moment-preview-bottom-sheet')
          : null,
      isRecommendation: true,
    );
  }

  void _openMomentPlayer(BuildContext context, MomentListItem item) {
    unawaited(
      playMomentItem(context: context, item: item, fallbackPath: _fallbackPath),
    );
  }

  void _openMomentMovie(BuildContext context, MomentListItem item) {
    openMomentSourceMovie(
      context: context,
      item: item,
      fallbackPath: _fallbackPath,
    );
  }

  void _addMomentToCollection(BuildContext context, MomentListItem item) {
    unawaited(
      addMomentItemToCollection(context, item: item, isRecommendation: true),
    );
  }
}

class _DiscoveryMovieRailSection extends StatelessWidget {
  const _DiscoveryMovieRailSection({
    required this.title,
    required this.actionKey,
    required this.actionSize,
    required this.onMore,
    required this.total,
    required this.isLoading,
    required this.items,
    required this.errorMessage,
    required this.emptyMessage,
    required this.retryKey,
    required this.onRetry,
    required this.onMovieTap,
    required this.onMovieMenuRequest,
    this.secondaryLabelForMovie,
    this.useDefaultSubscriptionActions = false,
    this.onMovieSubscriptionTap,
    this.isMovieSubscriptionUpdating,
    this.hoverActions,
    required this.placeholderCount,
  });

  final String title;
  final Key actionKey;
  final AppTextButtonSize actionSize;
  final VoidCallback onMore;
  final int total;
  final bool isLoading;
  final List<MovieListItemDto> items;
  final String? errorMessage;
  final String emptyMessage;
  final Key retryKey;
  final Future<void> Function() onRetry;
  final ValueChanged<MovieListItemDto> onMovieTap;
  final void Function(MovieListItemDto movie, Offset globalPosition)
  onMovieMenuRequest;
  final String? Function(MovieListItemDto movie)? secondaryLabelForMovie;
  final bool useDefaultSubscriptionActions;
  final ValueChanged<MovieListItemDto>? onMovieSubscriptionTap;
  final bool Function(MovieListItemDto movie)? isMovieSubscriptionUpdating;
  final MovieCardHoverFeatureActions? hoverActions;
  final int placeholderCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: title,
          trailingText: l10n.sharedMovieCount(total),
          actionKey: actionKey,
          actionLabel: l10n.sharedMore,
          actionSize: actionSize,
          onActionTap: onMore,
        ),
        SizedBox(height: context.appSpacing.md),
        if (errorMessage != null)
          DiscoveryRetryEmptyState(
            message: errorMessage!,
            onRetry: onRetry,
            retryKey: retryKey,
          )
        else
          AppSkeletonizer(
            enabled: isLoading,
            child: MovieSummaryRail(
              items: isLoading
                  ? movieListItemPlaceholders(count: placeholderCount)
                  : items,
              emptyMessage: emptyMessage,
              secondaryLabelForMovie: secondaryLabelForMovie,
              useDefaultSubscriptionActions: useDefaultSubscriptionActions,
              onMovieTap: onMovieTap,
              onMovieMenuRequest: onMovieMenuRequest,
              onMovieSubscriptionTap: onMovieSubscriptionTap,
              isMovieSubscriptionUpdating: isMovieSubscriptionUpdating,
              onMovieToggleCollectionType: hoverActions?.toggleCollectionType,
              onMovieBlacklist: hoverActions?.blacklist,
            ),
          ),
      ],
    );
  }
}

class _DiscoveryMomentSection extends StatelessWidget {
  const _DiscoveryMomentSection({
    required this.actionKey,
    required this.actionSize,
    required this.onMore,
    required this.total,
    required this.isLoading,
    required this.items,
    required this.errorMessage,
    required this.emptyMessage,
    required this.retryKey,
    required this.onRetry,
    required this.previewSize,
    required this.onItemTap,
    required this.onItemPlay,
    required this.onItemOpenMovie,
    required this.onItemAddToCollection,
  });

  final Key actionKey;
  final AppTextButtonSize actionSize;
  final VoidCallback onMore;
  final int total;
  final bool isLoading;
  final List<MomentRecommendationDto> items;
  final String? errorMessage;
  final String emptyMessage;
  final Key retryKey;
  final Future<void> Function() onRetry;
  final int previewSize;
  final ValueChanged<MomentListItem> onItemTap;
  final ValueChanged<MomentListItem> onItemPlay;
  final ValueChanged<MomentListItem> onItemOpenMovie;
  final ValueChanged<MomentListItem> onItemAddToCollection;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: l10n.discoveryMomentTitle,
          trailingText: l10n.sharedMomentCount(total),
          actionKey: actionKey,
          actionLabel: l10n.sharedMore,
          actionSize: actionSize,
          onActionTap: onMore,
        ),
        SizedBox(height: context.appSpacing.md),
        if (isLoading)
          AppSkeletonizer(
            enabled: true,
            child: MomentRail(
              items: momentListPlaceholders(count: previewSize),
              onItemTap: (_) {},
            ),
          )
        else if (errorMessage != null)
          DiscoveryRetryEmptyState(
            message: errorMessage!,
            onRetry: onRetry,
            retryKey: retryKey,
          )
        else if (items.isEmpty)
          AppEmptyState(message: emptyMessage)
        else
          MomentRail(
            items: items
                .take(previewSize)
                .map((item) => item.toMomentListItem())
                .toList(growable: false),
            onItemTap: onItemTap,
            onItemPlay: onItemPlay,
            onItemOpenMovie: onItemOpenMovie,
            onItemAddToCollection: onItemAddToCollection,
          ),
      ],
    );
  }
}
