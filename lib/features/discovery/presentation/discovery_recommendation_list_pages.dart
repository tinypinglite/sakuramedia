import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/discovery/data/daily_recommendation_movie_dto.dart';
import 'package:sakuramedia/features/discovery/data/discovery_api.dart';
import 'package:sakuramedia/features/discovery/data/moment_recommendation_dto.dart';
import 'package:sakuramedia/features/discovery/presentation/discovery_controller.dart';
import 'package:sakuramedia/features/image_search/presentation/desktop_image_search_launcher.dart';
import 'package:sakuramedia/features/moments/presentation/paged_moment_controller.dart';
import 'package:sakuramedia/features/shared/presentation/paged_load_controller.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/app_filter_total_header.dart';
import 'package:sakuramedia/widgets/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/media/media_preview_dialog.dart';
import 'package:sakuramedia/widgets/moments/moment_grid.dart';
import 'package:sakuramedia/widgets/moments/moment_preview_dialog.dart';
import 'package:sakuramedia/widgets/movies/movie_summary_grid.dart';

class DesktopDiscoverMoviesPage extends StatelessWidget {
  const DesktopDiscoverMoviesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DiscoveryMoviesPage(platform: _DiscoveryListPlatform.desktop);
  }
}

class DesktopDiscoverMomentsPage extends StatelessWidget {
  const DesktopDiscoverMomentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DiscoveryMomentsPage(
      platform: _DiscoveryListPlatform.desktop,
    );
  }
}

class MobileDiscoverMoviesPage extends StatelessWidget {
  const MobileDiscoverMoviesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DiscoveryMoviesPage(platform: _DiscoveryListPlatform.mobile);
  }
}

class MobileDiscoverMomentsPage extends StatelessWidget {
  const MobileDiscoverMomentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DiscoveryMomentsPage(platform: _DiscoveryListPlatform.mobile);
  }
}

enum _DiscoveryListPlatform { desktop, mobile }

class _DiscoveryMoviesPage extends StatefulWidget {
  const _DiscoveryMoviesPage({required this.platform});

  final _DiscoveryListPlatform platform;

  @override
  State<_DiscoveryMoviesPage> createState() => _DiscoveryMoviesPageState();
}

class _DiscoveryMoviesPageState extends State<_DiscoveryMoviesPage> {
  late final PagedLoadController<DailyRecommendationMovieDto> _controller;

  bool get _isMobile => widget.platform == _DiscoveryListPlatform.mobile;

  @override
  void initState() {
    super.initState();
    _controller = PagedLoadController<DailyRecommendationMovieDto>(
      fetchPage:
          (page, pageSize) => context
              .read<DiscoveryApi>()
              .getDailyRecommendations(page: page, pageSize: pageSize),
      pageSize: _isMobile ? 18 : 24,
      loadMoreTriggerOffset: 300,
      initialLoadErrorText: '推荐影片加载失败，请稍后重试',
      loadMoreErrorText: '加载更多推荐影片失败，请点击重试',
    );
    _controller.attachScrollListener();
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final showFooter =
            _controller.items.isNotEmpty &&
            (_controller.isLoadingMore ||
                _controller.loadMoreErrorMessage != null);
        return Column(
          key: Key(
            _isMobile
                ? 'mobile-discover-movies-page'
                : 'desktop-discover-movies-page',
          ),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppFilterTotalHeader(
              leading: const SizedBox.shrink(),
              totalText: '${_controller.total} 部',
              totalKey: Key(
                _isMobile
                    ? 'mobile-discover-movies-total'
                    : 'desktop-discover-movies-total',
              ),
            ),
            SizedBox(
              height: _isMobile ? context.appSpacing.md : context.appSpacing.lg,
            ),
            _buildBody(context),
            if (showFooter) ...[
              SizedBox(height: context.appSpacing.md),
              AppPagedLoadMoreFooter(
                isLoading: _controller.isLoadingMore,
                errorMessage: _controller.loadMoreErrorMessage,
                onRetry: _controller.loadMore,
              ),
            ],
          ],
        );
      },
    );

    if (_isMobile) {
      return ColoredBox(
        color: context.appColors.surfaceCard,
        child: AppAdaptiveRefreshScrollView(
          controller: _controller.scrollController,
          onRefresh: _handleRefresh,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[SliverToBoxAdapter(child: child)],
        ),
      );
    }

    return ColoredBox(
      color: context.appColors.surfaceElevated,
      child: SingleChildScrollView(
        controller: _controller.scrollController,
        child: child,
      ),
    );
  }

  Future<void> _handleRefresh() async {
    try {
      await _controller.refresh();
    } catch (_) {
      if (mounted) {
        showToast('刷新失败');
      }
    }
  }

  Widget _buildBody(BuildContext context) {
    if (_controller.initialErrorMessage != null) {
      return _RetryEmptyState(
        message: _controller.initialErrorMessage!,
        onRetry: _controller.reload,
      );
    }
    return MovieSummaryGrid(
      items: _controller.items
          .map((item) => item.movie)
          .toList(growable: false),
      isLoading: _controller.isInitialLoading,
      emptyMessage: '暂无推荐影片',
      placeholderCount: _isMobile ? 6 : 12,
      onMovieTap: (movie) => _openMovieDetail(movie.movieNumber),
    );
  }

  void _openMovieDetail(String movieNumber) {
    context.push(_movieDetailPath(movieNumber, isMobile: _isMobile));
  }
}

class _DiscoveryMomentsPage extends StatefulWidget {
  const _DiscoveryMomentsPage({required this.platform});

  final _DiscoveryListPlatform platform;

  @override
  State<_DiscoveryMomentsPage> createState() => _DiscoveryMomentsPageState();
}

class _DiscoveryMomentsPageState extends State<_DiscoveryMomentsPage> {
  late final PagedLoadController<MomentRecommendationDto> _controller;

  bool get _isMobile => widget.platform == _DiscoveryListPlatform.mobile;

  @override
  void initState() {
    super.initState();
    _controller = PagedLoadController<MomentRecommendationDto>(
      fetchPage: _fetchPage,
      pageSize: _isMobile ? 18 : 24,
      loadMoreTriggerOffset: 300,
      initialLoadErrorText: '推荐时刻加载失败，请稍后重试',
      loadMoreErrorText: '加载更多推荐时刻失败，请点击重试',
    );
    _controller.attachScrollListener();
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<PaginatedResponseDto<MomentRecommendationDto>> _fetchPage(
    int page,
    int pageSize,
  ) async {
    final response = await context
        .read<DiscoveryApi>()
        .getMomentRecommendations(page: page, pageSize: pageSize);
    return PaginatedResponseDto<MomentRecommendationDto>(
      items: response.items,
      page: response.page,
      pageSize: response.pageSize,
      total: response.total,
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final showFooter =
            _controller.items.isNotEmpty &&
            (_controller.isLoadingMore ||
                _controller.loadMoreErrorMessage != null);
        return Column(
          key: Key(
            _isMobile
                ? 'mobile-discover-moments-page'
                : 'desktop-discover-moments-page',
          ),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppFilterTotalHeader(
              leading: const SizedBox.shrink(),
              totalText: '${_controller.total} 个',
              totalKey: Key(
                _isMobile
                    ? 'mobile-discover-moments-total'
                    : 'desktop-discover-moments-total',
              ),
            ),
            SizedBox(
              height: _isMobile ? context.appSpacing.md : context.appSpacing.lg,
            ),
            _buildBody(context),
            if (showFooter) ...[
              SizedBox(height: context.appSpacing.md),
              AppPagedLoadMoreFooter(
                isLoading: _controller.isLoadingMore,
                errorMessage: _controller.loadMoreErrorMessage,
                onRetry: _controller.loadMore,
              ),
            ],
          ],
        );
      },
    );

    if (_isMobile) {
      return ColoredBox(
        color: context.appColors.surfaceCard,
        child: AppAdaptiveRefreshScrollView(
          controller: _controller.scrollController,
          onRefresh: _handleRefresh,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[SliverToBoxAdapter(child: child)],
        ),
      );
    }

    return ColoredBox(
      color: context.appColors.surfaceElevated,
      child: SingleChildScrollView(
        controller: _controller.scrollController,
        child: child,
      ),
    );
  }

  Future<void> _handleRefresh() async {
    try {
      await _controller.refresh();
    } catch (_) {
      if (mounted) {
        showToast('刷新失败');
      }
    }
  }

  Widget _buildBody(BuildContext context) {
    if (_controller.isInitialLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: context.appLayoutTokens.emptySectionVerticalPadding,
          ),
          child: const CircularProgressIndicator(),
        ),
      );
    }
    if (_controller.initialErrorMessage != null) {
      return _RetryEmptyState(
        message: _controller.initialErrorMessage!,
        onRetry: _controller.reload,
      );
    }
    if (_controller.items.isEmpty) {
      return const AppEmptyState(message: '暂无推荐时刻');
    }
    return MomentGrid(
      items: _controller.items
          .map((item) => item.toMomentListItem())
          .toList(growable: false),
      onItemTap: _openMomentPreview,
    );
  }

  Future<void> _openMomentPreview(MomentListItem item) async {
    if (!_isMobile) {
      return showDialog<void>(
        context: context,
        builder:
            (dialogContext) => MomentPreviewDialog(
              item: item,
              onSearchSimilar: () => _searchSimilarFromMoment(item),
              onPlay: () => _openPlayerForMoment(item),
              onOpenMovieDetail: () => _openMovieDetailForMoment(item),
            ),
      );
    }

    _MomentPreviewAction? selectedAction;
    final preview = MomentPreviewDialog(
      item: item,
      presentation: MediaPreviewPresentation.bottomDrawer,
      onSearchSimilar: () async {
        selectedAction = _MomentPreviewAction.searchSimilar;
        return true;
      },
      onPlay: () => selectedAction = _MomentPreviewAction.play,
      onOpenMovieDetail:
          () => selectedAction = _MomentPreviewAction.movieDetail,
    );

    await showAppBottomDrawer<void>(
      context: context,
      maxHeightFactor: 0.7,
      drawerKey: const Key('mobile-discover-moments-preview-bottom-sheet'),
      ignoreTopSafeArea: true,
      builder: (_) => preview,
    );

    if (!mounted || selectedAction == null) {
      return;
    }
    switch (selectedAction!) {
      case _MomentPreviewAction.searchSimilar:
        await _searchSimilarFromMoment(item);
        break;
      case _MomentPreviewAction.play:
        _openPlayerForMoment(item);
        break;
      case _MomentPreviewAction.movieDetail:
        _openMovieDetailForMoment(item);
        break;
    }
  }

  Future<bool> _searchSimilarFromMoment(MomentListItem item) async {
    final imageUrl = resolveMomentImageUrl(item);
    if (imageUrl.isEmpty) {
      return false;
    }
    if (_isMobile) {
      try {
        await launchImageSearchFromUrl(
          context,
          imageUrl: imageUrl,
          routePath: mobileImageSearchPath,
          fallbackPath: mobileOverviewPath,
          fileName: buildMomentImageFileName(item, imageUrl),
        );
        return true;
      } catch (_) {
        if (mounted) {
          showToast('读取结果图片失败，请稍后重试');
        }
        return false;
      }
    }
    await launchDesktopImageSearchFromUrl(
      context,
      imageUrl: imageUrl,
      fallbackPath: desktopDiscoverMomentsPath,
      fileName: buildMomentImageFileName(item, imageUrl),
    );
    return true;
  }

  void _openPlayerForMoment(MomentListItem item) {
    final path = _moviePlayerPath(
      item.movieNumber,
      mediaId: item.mediaId > 0 ? item.mediaId : null,
      positionSeconds: item.offsetSeconds,
      isMobile: _isMobile,
    );
    context.push(path);
  }

  void _openMovieDetailForMoment(MomentListItem item) {
    context.push(_movieDetailPath(item.movieNumber, isMobile: _isMobile));
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
          label: '重试',
          size: AppButtonSize.small,
          onPressed: () => unawaited(onRetry()),
        ),
      ],
    );
  }
}

String _movieDetailPath(String movieNumber, {required bool isMobile}) {
  final encoded = Uri.encodeComponent(movieNumber);
  return isMobile
      ? '$mobileMoviesPath/$encoded'
      : '$desktopMoviesPath/$encoded';
}

String _moviePlayerPath(
  String movieNumber, {
  required bool isMobile,
  int? mediaId,
  int? positionSeconds,
}) {
  final encoded = Uri.encodeComponent(movieNumber);
  final basePath = isMobile ? mobileMoviesPath : desktopMoviesPath;
  return Uri(
    path: '$basePath/$encoded/player',
    queryParameters: <String, String>{
      if (mediaId != null) 'mediaId': '$mediaId',
      if (positionSeconds != null) 'positionSeconds': '$positionSeconds',
    },
  ).toString();
}

enum _MomentPreviewAction { searchSimilar, play, movieDetail }
