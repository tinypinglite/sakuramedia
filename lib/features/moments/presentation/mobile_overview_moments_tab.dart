import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/image_search/presentation/desktop_image_search_launcher.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/moments/presentation/paged_moment_controller.dart';
import 'package:sakuramedia/features/movies/presentation/movie_playback_launcher.dart';
import 'package:sakuramedia/features/videos/presentation/mobile_video_player_page.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/media/media_preview_dialog.dart';
import 'package:sakuramedia/widgets/moments/moment_grid.dart';
import 'package:sakuramedia/widgets/moments/moment_preview_dialog.dart';
import 'package:sakuramedia/widgets/moments/moment_sort_header.dart';

class MobileOverviewMomentsTab extends StatefulWidget {
  const MobileOverviewMomentsTab({super.key});

  @override
  State<MobileOverviewMomentsTab> createState() =>
      _MobileOverviewMomentsTabState();
}

class _MobileOverviewMomentsTabState extends State<MobileOverviewMomentsTab> {
  late final PagedMomentController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PagedMomentController(
      fetchPage:
          (page, pageSize, sort, kind) => context
              .read<MediaApi>()
              .getGlobalMediaPoints(
                page: page,
                pageSize: pageSize,
                sort: sort,
                kind: kind,
              ),
      pageSize: 20,
      loadMoreTriggerOffset: 300,
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
    return ColoredBox(
      color: context.appColors.surfaceCard,
      child: AppAdaptiveRefreshScrollView(
        onRefresh: _handleRefresh,
        controller: _controller.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final showFooter =
                    _controller.items.isNotEmpty &&
                    (_controller.isLoadingMore ||
                        _controller.loadMoreErrorMessage != null);
                return Column(
                  key: const Key('mobile-overview-moments-tab'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: context.appSpacing.sm),
                    MomentSortHeader(
                      total: _controller.total,
                      sortOrder: _controller.sortOrder,
                      kindFilter: _controller.kindFilter,
                      variant: MomentSortHeaderVariant.mobileTagCompact,
                      latestSortKey: const Key('mobile-moments-sort-latest'),
                      earliestSortKey: const Key(
                        'mobile-moments-sort-earliest',
                      ),
                      totalKey: const Key('mobile-moments-page-total'),
                      kindJavKey: const Key('mobile-moments-kind-jav'),
                      kindVideoKey: const Key('mobile-moments-kind-video'),
                      onSortChanged:
                          (nextOrder) =>
                              unawaited(_controller.setSortOrder(nextOrder)),
                      onKindChanged:
                          (nextKind) =>
                              unawaited(_controller.setKindFilter(nextKind)),
                    ),
                    SizedBox(height: context.appSpacing.md),
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
            ),
          ),
        ],
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
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_controller.initialErrorMessage != null) {
      return AppEmptyState(message: _controller.initialErrorMessage!);
    }

    if (_controller.items.isEmpty) {
      return const AppEmptyState(message: '暂无时刻数据');
    }

    return MomentGrid(items: _controller.items, onItemTap: _openMomentPreview);
  }

  Future<void> _openMomentPreview(MomentListItem item) async {
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
          item.isVideo
              ? null
              : () => selectedAction = _MomentPreviewAction.movieDetail,
      onPointRemoved: () => unawaited(_controller.reload()),
      closeOnPointRemoved: true,
    );

    await showAppBottomDrawer<void>(
      context: context,
      maxHeightFactor: 0.7,
      drawerKey: const Key('mobile-moments-preview-bottom-sheet'),
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

  Future<void> _searchSimilarFromMoment(MomentListItem item) async {
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
      if (mounted) {
        showToast('读取结果图片失败，请稍后重试');
      }
    }
  }

  void _openPlayerForMoment(MomentListItem item) {
    if (item.isVideo) {
      // 与 mobile_pornbox_page 对齐：推到独立全屏播放页；不支持 startPosition。
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => MobileVideoPlayerPage(
            videoId: item.videoItemId!,
            title: item.displayLabel,
          ),
        ),
      );
      return;
    }
    unawaited(
      launchMoviePlayback(
        context,
        movieNumber: item.movieNumber!,
        mediaId: item.mediaId > 0 ? item.mediaId : null,
        positionSeconds: item.offsetSeconds,
      ),
    );
  }

  void _openMovieDetailForMoment(MomentListItem item) {
    if (item.isVideo) {
      // 视频域无详情页，对话框侧已隐藏入口，此处兜底。
      return;
    }
    MobileMovieDetailRouteData(movieNumber: item.movieNumber!).push(context);
  }
}

enum _MomentPreviewAction { searchSimilar, play, movieDetail }
