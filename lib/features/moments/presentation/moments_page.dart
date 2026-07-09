import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/image_search/presentation/desktop_image_search_launcher.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/moments/presentation/paged_moment_controller.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_playback_launcher.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/video_player_page.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_skeleton.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/domain/media/preview/media_preview_dialog.dart';
import 'package:sakuramedia/widgets/domain/media/quick_play_dialog.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_grid.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_image.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_preview_launcher.dart';
import 'package:sakuramedia/widgets/domain/moments/moment_sort_header.dart';

enum MomentsPagePlatform { desktop, mobile }

class MomentsPage extends StatefulWidget {
  const MomentsPage({super.key, required this.platform});

  final MomentsPagePlatform platform;

  @override
  State<MomentsPage> createState() => _MomentsPageState();
}

class _MomentsPageState extends State<MomentsPage> {
  late final PagedMomentController _controller;

  bool get _isMobile => widget.platform == MomentsPagePlatform.mobile;

  String get _keyPrefix => _isMobile ? 'mobile-moments' : 'moments';

  @override
  void initState() {
    super.initState();
    _controller = PagedMomentController(
      fetchPage: (page, pageSize, sort, kind) =>
          context.read<MediaApi>().getGlobalMediaPoints(
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
                final showFooter = _controller.items.isNotEmpty &&
                    (_controller.isLoadingMore ||
                        _controller.loadMoreErrorMessage != null);
                return Column(
                  key: Key(
                    _isMobile ? 'mobile-overview-moments-tab' : 'moments-page',
                  ),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: context.appSpacing.sm),
                    MomentSortHeader(
                      total: _controller.total,
                      sortOrder: _controller.sortOrder,
                      kindFilter: _controller.kindFilter,
                      keyPrefix: _keyPrefix,
                      onSortChanged: (nextOrder) =>
                          unawaited(_controller.setSortOrder(nextOrder)),
                      onKindChanged: (nextKind) =>
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
      return const AppMobileSkeletonList();
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
    final presentation = _isMobile
        ? MediaPreviewPresentation.bottomDrawer
        : MediaPreviewPresentation.dialog;
    final action = await showMomentPreviewOverlay(
      context: context,
      item: item,
      presentation: presentation,
      drawerKey:
          _isMobile ? const Key('mobile-moments-preview-bottom-sheet') : null,
      onPointRemoved: () => unawaited(_controller.reload()),
      closeOnPointRemoved: true,
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case MediaPreviewAction.searchSimilar:
        await _searchSimilarFromMoment(item);
      case MediaPreviewAction.play:
        _openPlayerForMoment(item);
      case MediaPreviewAction.openMovieDetail:
        _openMovieDetailForMoment(item);
    }
  }

  Future<void> _searchSimilarFromMoment(MomentListItem item) async {
    final imageUrl = resolveMomentImageUrl(item);
    if (imageUrl.isEmpty) {
      return;
    }
    try {
      if (_isMobile) {
        await launchImageSearchFromUrl(
          context,
          imageUrl: imageUrl,
          routePath: mobileImageSearchPath,
          fallbackPath: mobileOverviewPath,
          fileName: buildMomentImageFileName(item, imageUrl),
        );
      } else {
        await launchDesktopImageSearchFromUrl(
          context,
          imageUrl: imageUrl,
          fallbackPath: desktopMomentsPath,
          fileName: buildMomentImageFileName(item, imageUrl),
        );
      }
    } catch (_) {
      if (mounted) {
        showToast('读取结果图片失败，请稍后重试');
      }
    }
  }

  void _openPlayerForMoment(MomentListItem item) {
    if (item.isVideo) {
      if (_isMobile) {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => MobileVideoPlayerPage(
              videoId: item.videoItemId!,
              title: item.displayLabel,
            ),
          ),
        );
      } else {
        unawaited(
          showVideoQuickPlayDialog(
            context,
            videoId: item.videoItemId!,
            title: item.displayLabel,
          ),
        );
      }
      return;
    }

    if (_isMobile) {
      unawaited(
        launchMoviePlayback(
          context,
          movieNumber: item.movieNumber!,
          mediaId: item.mediaId > 0 ? item.mediaId : null,
          positionSeconds: item.offsetSeconds,
        ),
      );
      return;
    }

    context.pushDesktopMoviePlayer(
      movieNumber: item.movieNumber!,
      fallbackPath: desktopMomentsPath,
      mediaId: item.mediaId > 0 ? item.mediaId : null,
      positionSeconds: item.offsetSeconds,
    );
  }

  void _openMovieDetailForMoment(MomentListItem item) {
    if (item.isVideo) {
      return;
    }
    if (_isMobile) {
      MobileMovieDetailRouteData(movieNumber: item.movieNumber!).push(context);
      return;
    }
    context.pushDesktopMovieDetail(
      movieNumber: item.movieNumber!,
      fallbackPath: desktopMomentsPath,
    );
  }
}
