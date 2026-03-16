import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/image_search/presentation/desktop_image_search_launcher.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/moments/presentation/paged_moment_controller.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/moments/moment_grid.dart';
import 'package:sakuramedia/widgets/moments/moment_preview_dialog.dart';
import 'package:sakuramedia/widgets/moments/moment_sort_header.dart';

class DesktopMomentsPage extends StatefulWidget {
  const DesktopMomentsPage({super.key});

  @override
  State<DesktopMomentsPage> createState() => _DesktopMomentsPageState();
}

class _DesktopMomentsPageState extends State<DesktopMomentsPage> {
  late final PagedMomentController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PagedMomentController(
      fetchPage:
          (page, pageSize, sort) => context
              .read<MediaApi>()
              .getGlobalMediaPoints(page: page, pageSize: pageSize, sort: sort),
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
      color: context.appColors.surfaceElevated,
      child: SingleChildScrollView(
        controller: _controller.scrollController,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final footer = _buildLoadMoreFooter(context);
            return Column(
              key: const Key('moments-page'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MomentSortHeader(
                  total: _controller.total,
                  sortOrder: _controller.sortOrder,
                  onSortChanged:
                      (nextOrder) =>
                          unawaited(_controller.setSortOrder(nextOrder)),
                ),
                SizedBox(height: context.appSpacing.lg),
                _buildBody(context),
                if (footer != null) ...[
                  SizedBox(height: context.appSpacing.md),
                  footer,
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_controller.isInitialLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
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

  Widget? _buildLoadMoreFooter(BuildContext context) {
    if (_controller.items.isEmpty ||
        (!_controller.isLoadingMore &&
            _controller.loadMoreErrorMessage == null)) {
      return null;
    }

    return AppPagedLoadMoreFooter(
      isLoading: _controller.isLoadingMore,
      errorMessage: _controller.loadMoreErrorMessage,
      onRetry: _controller.loadMore,
    );
  }

  Future<void> _openMomentPreview(MomentListItem item) {
    return showDialog<void>(
      context: context,
      builder:
          (dialogContext) => MomentPreviewDialog(
            item: item,
            onSearchSimilar:
                resolveMomentImageUrl(item).isEmpty
                    ? null
                    : () => _searchSimilarFromMoment(item),
            onPlay: () => _openPlayerForMoment(item),
            onOpenMovieDetail: () => _openMovieDetailForMoment(item),
            onPointRemoved: () => unawaited(_controller.reload()),
            closeOnPointRemoved: true,
          ),
    );
  }

  Future<bool> _searchSimilarFromMoment(MomentListItem item) async {
    final imageUrl = resolveMomentImageUrl(item);
    if (imageUrl.isEmpty) {
      return false;
    }
    await launchDesktopImageSearchFromUrl(
      context,
      imageUrl: imageUrl,
      fallbackPath: desktopMomentsPath,
      fileName: buildMomentImageFileName(item, imageUrl),
    );
    return true;
  }

  void _openPlayerForMoment(MomentListItem item) {
    context.push(
      buildDesktopMoviePlayerRoutePath(
        item.movieNumber,
        mediaId: item.mediaId > 0 ? item.mediaId : null,
        positionSeconds: item.offsetSeconds,
      ),
    );
  }

  void _openMovieDetailForMoment(MomentListItem item) {
    context.push(
      '$desktopMoviesPath/${Uri.encodeComponent(item.movieNumber)}',
      extra: desktopMomentsPath,
    );
  }
}
