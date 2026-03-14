import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/image_search/presentation/desktop_image_search_launcher.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/moments/presentation/paged_moment_controller.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/media/media_preview_dialog.dart';
import 'package:sakuramedia/widgets/moments/moment_grid.dart';

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
      fetchMediaThumbnails: context.read<MoviesApi>().getMediaThumbnails,
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
                _MomentsHeader(
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
    if (_controller.items.isEmpty) {
      return null;
    }

    final spacing = context.appSpacing;
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;

    if (_controller.isLoadingMore) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: spacing.md),
          child: SizedBox(
            width: componentTokens.movieCardLoaderSize,
            height: componentTokens.movieCardLoaderSize,
            child: CircularProgressIndicator(
              strokeWidth: componentTokens.movieCardLoaderStrokeWidth,
            ),
          ),
        ),
      );
    }

    if (_controller.loadMoreErrorMessage == null) {
      return null;
    }

    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: context.appRadius.mdBorder,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.lg,
            vertical: spacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: componentTokens.iconSizeXl,
                color: colors.textSecondary,
              ),
              SizedBox(width: spacing.sm),
              Text(
                _controller.loadMoreErrorMessage!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
              ),
              SizedBox(width: spacing.sm),
              TextButton(
                onPressed: _controller.loadMore,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing.sm,
                    vertical: spacing.xs,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMomentPreview(MomentListItem item) {
    final imageUrl = _momentImageUrl(item);
    return showDialog<void>(
      context: context,
      builder:
          (dialogContext) => MediaPreviewDialog(
            item: MediaPreviewItem(
              imageUrl: imageUrl,
              fileName: _momentImageFileName(item, imageUrl),
              mediaId: item.mediaId,
              movieNumber: item.movieNumber,
              offsetSeconds: item.offsetSeconds,
            ),
            onSearchSimilar:
                imageUrl.isEmpty ? null : () => _searchSimilarFromMoment(item),
            onPlay: () => _openPlayerForMoment(item),
            onOpenMovieDetail: () => _openMovieDetailForMoment(item),
            onPointRemoved: () => unawaited(_controller.reload()),
            closeOnPointRemoved: true,
          ),
    );
  }

  Future<bool> _searchSimilarFromMoment(MomentListItem item) async {
    final imageUrl = _momentImageUrl(item);
    if (imageUrl.isEmpty) {
      return false;
    }
    await launchDesktopImageSearchFromUrl(
      context,
      imageUrl: imageUrl,
      fallbackPath: desktopMomentsPath,
      fileName: _momentImageFileName(item, imageUrl),
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

  String _momentImageUrl(MomentListItem item) {
    final image = item.image;
    if (image == null) {
      return '';
    }
    final origin = image.origin.trim();
    if (origin.isNotEmpty) {
      return origin;
    }
    return image.bestAvailableUrl;
  }

  String _momentImageFileName(MomentListItem item, String imageUrl) {
    final extension = guessImageFileExtension(imageUrl, fallback: 'webp');
    return 'moment_${item.movieNumber}_${item.pointId}.$extension';
  }
}

class _MomentsHeader extends StatelessWidget {
  const _MomentsHeader({
    required this.total,
    required this.sortOrder,
    required this.onSortChanged,
  });

  final int total;
  final MomentSortOrder sortOrder;
  final ValueChanged<MomentSortOrder> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppButton(
          key: const Key('moments-sort-latest'),
          label: MomentSortOrder.latest.label,
          size: AppButtonSize.small,
          isSelected: sortOrder == MomentSortOrder.latest,
          onPressed: () => onSortChanged(MomentSortOrder.latest),
        ),
        SizedBox(width: context.appSpacing.sm),
        AppButton(
          key: const Key('moments-sort-earliest'),
          label: MomentSortOrder.earliest.label,
          size: AppButtonSize.small,
          isSelected: sortOrder == MomentSortOrder.earliest,
          onPressed: () => onSortChanged(MomentSortOrder.earliest),
        ),
        const Spacer(),
        Text(
          '$total 个时刻',
          key: const Key('moments-page-total'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
