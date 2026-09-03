import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oktoast/oktoast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/core/media/image_save_service.dart';
import 'package:sakuramedia/features/clips/presentation/widgets/create_clip_dialog.dart';
import 'package:sakuramedia/features/media/data/media_point_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/thumbnails/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_review_dto.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_magnet_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_review_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_thumbnail_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_update_bar.dart';
import 'package:sakuramedia/widgets/domain/clips/clip_selection_status_bar.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_action_menu.dart';
import 'package:sakuramedia/widgets/base/media/images/thumbnail_grid_column_resolver.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_plot_preview_overlay.dart';
import 'package:sakuramedia/widgets/domain/media/movie_media_thumbnail_grid.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_magnet_search_content.dart';
import 'package:sakuramedia/widgets/base/navigation/app_tab_bar.dart';

class MovieDetailInspectorPanel extends ConsumerStatefulWidget {
  const MovieDetailInspectorPanel({
    super.key,
    required this.movieNumber,
    required this.selectedMedia,
    required this.onClose,
    this.showCloseButton = true,
    this.thumbnailPreviewPresentation = MoviePlotPreviewPresentation.dialog,
    this.onSearchSimilar,
    this.onPlay,
  });

  final String movieNumber;
  final MovieMediaItemDto? selectedMedia;
  final VoidCallback onClose;
  final bool showCloseButton;
  final MoviePlotPreviewPresentation thumbnailPreviewPresentation;
  final Future<void> Function(
    MovieMediaThumbnailDto thumbnail,
    String imageUrl,
    String fileName,
  )?
  onSearchSimilar;
  final void Function(MovieMediaThumbnailDto thumbnail)? onPlay;

  @override
  ConsumerState<MovieDetailInspectorPanel> createState() =>
      _MovieDetailInspectorPanelState();
}

class _MovieDetailInspectorPanelState
    extends ConsumerState<MovieDetailInspectorPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// 检查器三 provider 的 `KeepAliveLink` 收编表（key → link，去重用）。
  ///
  /// 三者都是 autoDispose family，build 里自持 `ref.keepAlive()`——link 必须
  /// 由**面板**关闭：面板打开期间保活（切 Tab 不丢已加载的评论/磁力/缩略图），
  /// [dispose] 时逐个 close → provider 释放。若无人 close 会形成「link 不关 →
  /// provider 永不 dispose → onDispose 里的 close 永不执行」的死锁式泄漏
  /// （见 `lib/features/AGENTS.md`「状态与数据」）。缩略图按 mediaId 分实例，
  /// 切换媒体源时新实例也要登记，故用 map 而非三个字段。
  final Map<String, KeepAliveLink> _retainedLinks = <String, KeepAliveLink>{};

  MovieDetailReview get _reviewController =>
      ref.read(movieDetailReviewProvider(widget.movieNumber).notifier);
  MovieDetailMagnet get _magnetController =>
      ref.read(movieDetailMagnetProvider(widget.movieNumber).notifier);
  MovieDetailThumbnail get _thumbnailController => ref.read(
    movieDetailThumbnailProvider(
      mediaId: widget.selectedMedia?.mediaId,
    ).notifier,
  );
  MovieDetailThumbnailState get _thumbnailState => ref.read(
    movieDetailThumbnailProvider(mediaId: widget.selectedMedia?.mediaId),
  );

  void _retainLink(String key, KeepAliveLink? link) {
    if (link == null || _retainedLinks.containsKey(key)) return;
    _retainedLinks[key] = link;
  }

  /// 登记当前 mediaId 对应的缩略图实例（初次挂载与切换媒体源时都要调）。
  void _retainThumbnailLink() {
    final mediaId = widget.selectedMedia?.mediaId;
    _retainLink('thumbnail:$mediaId', _thumbnailController.cacheLink);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
    // 收编在 initState 同步做（不等 post-frame）：link 是 provider 在 build 里
    // 自持的，只要 provider 被创建就已存在——晚一帧收编，中途被销毁就没人 close。
    _retainLink('review', _reviewController.cacheLink);
    _retainLink('magnet', _magnetController.cacheLink);
    _retainThumbnailLink();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_reviewController.loadInitial());
      unawaited(_thumbnailController.loadIfNeeded());
    });
  }

  @override
  void didUpdateWidget(covariant MovieDetailInspectorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMedia?.mediaId != widget.selectedMedia?.mediaId) {
      _retainThumbnailLink();
    }
  }

  @override
  void dispose() {
    for (final link in _retainedLinks.values) {
      link.close();
    }
    _retainedLinks.clear();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showThumbnailActions(int index, Offset globalPosition) async {
    final thumbnails = _thumbnailState.thumbnails;
    if (index < 0 || index >= thumbnails.length) {
      return;
    }
    final thumbnail = thumbnails[index];
    final point = await _loadMatchingPoint(thumbnail);
    if (!mounted) {
      return;
    }
    final action = await showAppImageActionMenu(
      context: context,
      actions: _buildThumbnailActionDescriptors(thumbnail, point),
      globalPosition: globalPosition,
    );
    if (!mounted || action == null) {
      return;
    }
    await _handleThumbnailAction(thumbnail, action, point);
  }

  Future<void> _handleCreateClip() async {
    final start = _thumbnailState.clipStartThumbnail;
    final end = _thumbnailState.clipEndThumbnail;
    if (start == null || end == null || start.mediaId <= 0) {
      return;
    }
    final created = await showCreateClipDialog(
      context,
      mediaId: start.mediaId,
      movieNumber: widget.movieNumber,
      startThumbnailId: start.thumbnailId,
      endThumbnailId: end.thumbnailId,
      startSeconds: start.offsetSeconds,
      endSeconds: end.offsetSeconds,
    );
    if (!mounted || created == null) {
      return;
    }
    showToast('切片已生成');
    // 退出圈选模式并清空已选点。
    _thumbnailController.toggleClipSelectionMode();
  }

  List<AppImageActionDescriptor> _buildThumbnailActionDescriptors(
    MovieMediaThumbnailDto thumbnail,
    MediaPointDto? point,
  ) {
    final hasMedia = thumbnail.mediaId > 0;
    return <AppImageActionDescriptor>[
      AppImageActionDescriptor(
        type: AppImageActionType.searchSimilar,
        label: '相似图片',
        icon: Icons.image_search_outlined,
        enabled: widget.onSearchSimilar != null,
      ),
      const AppImageActionDescriptor(
        type: AppImageActionType.saveToLocal,
        label: '保存到本地',
        icon: Icons.download_outlined,
      ),
      AppImageActionDescriptor(
        type: AppImageActionType.toggleMark,
        label: point == null ? '添加标记' : '删除标记',
        icon: point == null
            ? Icons.bookmark_add_outlined
            : Icons.bookmark_remove_outlined,
        enabled: hasMedia,
      ),
      AppImageActionDescriptor(
        type: AppImageActionType.play,
        label: '播放',
        icon: Icons.play_circle_outline_rounded,
        enabled: hasMedia && widget.onPlay != null,
      ),
    ];
  }

  Future<MediaPointDto?> _loadMatchingPoint(
    MovieMediaThumbnailDto thumbnail,
  ) async {
    if (thumbnail.mediaId <= 0 || thumbnail.thumbnailId <= 0) {
      return null;
    }
    final points = await ref
        .read(mediaApiProvider)
        .getMediaPoints(mediaId: thumbnail.mediaId);
    for (final point in points) {
      if (point.thumbnailId == thumbnail.thumbnailId) {
        return point;
      }
    }
    return null;
  }

  Future<void> _handleThumbnailAction(
    MovieMediaThumbnailDto thumbnail,
    AppImageActionType action,
    MediaPointDto? point,
  ) async {
    final imageUrl = thumbnail.image.resolvedUrl;
    final fileName =
        'movie_thumbnail_${widget.movieNumber}_${thumbnail.thumbnailId}.webp';

    switch (action) {
      case AppImageActionType.searchSimilar:
        final searchHandler = widget.onSearchSimilar;
        if (searchHandler == null) {
          return;
        }
        Navigator.of(context).pop();
        Future<void>.microtask(
          () => searchHandler(thumbnail, imageUrl, fileName),
        );
        break;
      case AppImageActionType.saveToLocal:
        final result =
            await ImageSaveService(
              fetchBytes: ref.read(apiClientProvider).getBytes,
            ).saveImageFromUrl(
              imageUrl: imageUrl,
              fileName: fileName,
              dialogTitle: '保存到本地',
            );
        if (!mounted) {
          return;
        }
        if (result.status == ImageSaveStatus.success) {
          showToast(result.message ?? '图片已保存');
        }
        if (result.status == ImageSaveStatus.failed) {
          showToast(result.message ?? '保存失败，请稍后重试');
        }
        break;
      case AppImageActionType.toggleMark:
        if (thumbnail.mediaId <= 0 || thumbnail.thumbnailId <= 0) {
          return;
        }
        try {
          if (point == null) {
            await ref
                .read(mediaApiProvider)
                .createMediaPoint(
                  mediaId: thumbnail.mediaId,
                  thumbnailId: thumbnail.thumbnailId,
                );
            if (mounted) {
              showToast('已添加标记');
            }
          } else {
            await ref
                .read(mediaApiProvider)
                .deleteMediaPoint(
                  mediaId: thumbnail.mediaId,
                  pointId: point.pointId,
                );
            if (mounted) {
              showToast('已删除标记');
            }
          }
        } catch (_) {
          if (mounted) {
            showToast('更新标记失败');
          }
        }
        break;
      case AppImageActionType.play:
        final playHandler = widget.onPlay;
        if (playHandler == null) {
          return;
        }
        Navigator.of(context).pop();
        Future<void>.microtask(() => playHandler(thumbnail));
        break;
      case AppImageActionType.movieDetail:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('movie-detail-inspector-panel'),
      children: [
        Row(
          children: [
            Expanded(
              child: AppTabBar(
                variant: AppTabBarVariant.compact,
                controller: _tabController,
                tabs: const <Widget>[
                  Tab(text: '评论'),
                  Tab(text: '磁力搜索'),
                  Tab(text: '缩略图'),
                ],
              ),
            ),
            // if (widget.showCloseButton)
            //   AppIconButton(
            //     tooltip: '关闭',
            //     onPressed: widget.onClose,
            //     icon: const Icon(Icons.close_rounded),
            //   ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _MovieDetailReviewTab(movieNumber: widget.movieNumber),
              MovieMagnetSearchContent(movieNumber: widget.movieNumber),
              _MovieDetailThumbnailTab(
                mediaId: widget.selectedMedia?.mediaId,
                thumbnailPreviewPresentation:
                    widget.thumbnailPreviewPresentation,
                onThumbnailMenuRequested: _showThumbnailActions,
                onCreateClip: _handleCreateClip,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MovieDetailReviewTab extends ConsumerStatefulWidget {
  const _MovieDetailReviewTab({required this.movieNumber});

  final String movieNumber;

  @override
  ConsumerState<_MovieDetailReviewTab> createState() =>
      _MovieDetailReviewTabState();
}

class _MovieDetailReviewTabState extends ConsumerState<_MovieDetailReviewTab> {
  MovieDetailReview get _controller =>
      ref.read(movieDetailReviewProvider(widget.movieNumber).notifier);
  MovieDetailReviewState get _state =>
      ref.read(movieDetailReviewProvider(widget.movieNumber));

  static const double _loadMoreExtentAfterThreshold = 200;
  late final ScrollController _scrollController;
  int _lastAutoLoadTriggerItemCount = -1;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.extentAfter >
        _loadMoreExtentAfterThreshold) {
      _lastAutoLoadTriggerItemCount = -1;
      return;
    }
    if (_state.items.length == _lastAutoLoadTriggerItemCount) {
      return;
    }
    _lastAutoLoadTriggerItemCount = _state.items.length;
    _controller.loadMore();
  }

  void _handleSortChange(MovieReviewSort sort) {
    if (_state.sort == sort) {
      return;
    }
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _lastAutoLoadTriggerItemCount = -1;
    unawaited(_controller.setSort(sort));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(movieDetailReviewProvider(widget.movieNumber));
    return Padding(
      padding: EdgeInsets.only(
        top: context.appSpacing.sm,
        bottom: context.appSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: context.appSpacing.xs,
            runSpacing: context.appSpacing.xs,
            children: [
              for (final sort in MovieReviewSort.values)
                AppTextButton(
                  key: Key('movie-detail-review-sort-${sort.apiValue}'),
                  label: sort.label,
                  size: AppTextButtonSize.xSmall,
                  isSelected: state.sort == sort,
                  onPressed: () => _handleSortChange(sort),
                ),
            ],
          ),
          AppFilterUpdateBar(
            state: state.filterUpdate,
            hasPreviousItems: state.items.isNotEmpty,
            onRetry: () => unawaited(_controller.retrySort()),
          ),
          SizedBox(height: context.appSpacing.sm),
          Expanded(
            child: AppFilterResultLoadingOverlay(
              isLoading: state.filterUpdate.isLoading,
              hasPreviousItems: state.items.isNotEmpty,
              child: _buildContent(context, state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, MovieDetailReviewState state) {
    if (state.filterUpdate.hasFailed && state.items.isEmpty) {
      return const SizedBox.shrink();
    }

    if (state.isInitialLoading && state.items.isEmpty) {
      return const _MovieDetailReviewLoadingList();
    }

    if (state.initialErrorMessage != null && state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              state.initialErrorMessage!,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
            SizedBox(height: context.appSpacing.md),
            AppButton(
              key: const Key('movie-detail-review-retry-button'),
              label: '重试',
              variant: AppButtonVariant.secondary,
              onPressed: _controller.loadInitial,
            ),
          ],
        ),
      );
    }

    if (state.items.isEmpty) {
      return const Center(child: AppEmptyState(message: '暂无评论'));
    }

    return ListView.separated(
      controller: _scrollController,
      key: const Key('movie-detail-review-list'),
      itemCount: state.items.length + 1,
      separatorBuilder: (context, index) =>
          SizedBox(height: context.appSpacing.sm),
      itemBuilder: (context, index) {
        if (index < state.items.length) {
          return _MovieDetailReviewCard(review: state.items[index]);
        }
        return _MovieDetailReviewFooter(
          state: state,
          onRetryLoadMore: _controller.loadMore,
        );
      },
    );
  }
}

class _MovieDetailReviewCard extends StatelessWidget {
  const _MovieDetailReviewCard({required this.review});

  final MovieReviewDto review;

  @override
  Widget build(BuildContext context) {
    final reviewDate = review.createdAt == null
        ? '--/--/--'
        : DateFormat('yy/MM/dd').format(review.createdAt!.toLocal());
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.appSpacing.md),
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.mdBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: context.appSpacing.xs,
            runSpacing: context.appSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                review.username.trim().isEmpty ? '匿名用户' : review.username,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
              Text(
                reviewDate,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star_rounded,
                    size: context.appComponentTokens.iconSizeXs,
                    color: context.appColors.movieDetailScoreIcon,
                  ),
                  SizedBox(width: context.appSpacing.xs),
                  Text(
                    '${review.score}',
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      weight: AppTextWeight.regular,
                      tone: AppTextTone.muted,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.thumb_up_alt_rounded,
                    size: context.appComponentTokens.iconSizeXs,
                    color: context.appColors.movieCardPlayableBadgeBackground,
                  ),
                  SizedBox(width: context.appSpacing.xs),
                  Text(
                    '${review.likeCount}',
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      weight: AppTextWeight.regular,
                      tone: AppTextTone.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: context.appSpacing.xs),
          Text(
            review.content.trim().isEmpty ? '暂无评论内容' : review.content,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MovieDetailReviewFooter extends StatelessWidget {
  const _MovieDetailReviewFooter({
    required this.state,
    required this.onRetryLoadMore,
  });

  final MovieDetailReviewState state;
  final VoidCallback onRetryLoadMore;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingMore) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.appSpacing.sm),
        child: Center(
          child: CircularProgressIndicator.adaptive(
            key: Key('movie-detail-review-load-more-progress'),
          ),
        ),
      );
    }

    if (state.loadMoreErrorMessage != null) {
      return Column(
        key: const Key('movie-detail-review-load-more-error'),
        children: [
          Text(
            state.loadMoreErrorMessage!,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(height: context.appSpacing.sm),
          AppButton(
            key: const Key('movie-detail-review-load-more-retry-button'),
            label: '重试加载更多',
            size: AppButtonSize.xSmall,
            variant: AppButtonVariant.secondary,
            onPressed: onRetryLoadMore,
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

class _MovieDetailReviewLoadingList extends StatelessWidget {
  const _MovieDetailReviewLoadingList();

  static const int _minimumSkeletonCount = 3;
  static const double _skeletonLineHeight = 12;
  static const int _skeletonLineCount = 3;
  static const int _internalGapCount = 2;

  int _resolveSkeletonCount(BuildContext context, BoxConstraints constraints) {
    final availableHeight = constraints.maxHeight;
    if (!availableHeight.isFinite) {
      return _minimumSkeletonCount;
    }

    final spacing = context.appSpacing;
    final itemHeight =
        (spacing.md * 2) +
        (_skeletonLineHeight * _skeletonLineCount) +
        (spacing.xs * _internalGapCount);
    final separatorHeight = spacing.sm;
    final estimatedCount =
        ((availableHeight + separatorHeight) / (itemHeight + separatorHeight))
            .ceil();
    return math.max(_minimumSkeletonCount, estimatedCount);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemCount = _resolveSkeletonCount(context, constraints);
        return ListView.separated(
          itemCount: itemCount,
          separatorBuilder: (context, index) =>
              SizedBox(height: context.appSpacing.sm),
          itemBuilder: (context, index) {
            return Container(
              key: Key('movie-detail-review-skeleton-$index'),
              padding: EdgeInsets.all(context.appSpacing.md),
              decoration: BoxDecoration(
                color: context.appColors.surfaceMuted,
                borderRadius: context.appRadius.mdBorder,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ReviewSkeletonLine(width: 232),
                  SizedBox(height: context.appSpacing.xs),
                  _ReviewSkeletonLine(width: double.infinity),
                  SizedBox(height: context.appSpacing.xs),
                  _ReviewSkeletonLine(width: 296),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ReviewSkeletonLine extends StatelessWidget {
  const _ReviewSkeletonLine({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 12,
      decoration: BoxDecoration(
        color: context.appColors.borderSubtle,
        borderRadius: context.appRadius.smBorder,
      ),
    );
  }
}

class _MovieDetailThumbnailTab extends ConsumerWidget {
  static const List<int> _intervalOptions = <int>[10, 20, 30, 60];
  static const List<int> _columnOptions = <int>[2, 3, 4, 5];

  const _MovieDetailThumbnailTab({
    required this.mediaId,
    required this.thumbnailPreviewPresentation,
    this.onThumbnailMenuRequested,
    this.onCreateClip,
  });

  final int? mediaId;
  final MoviePlotPreviewPresentation thumbnailPreviewPresentation;
  final void Function(int index, Offset globalPosition)?
  onThumbnailMenuRequested;
  final VoidCallback? onCreateClip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(movieDetailThumbnailProvider(mediaId: mediaId));
    final controller = ref.read(
      movieDetailThumbnailProvider(mediaId: mediaId).notifier,
    );
    final thumbnails = state.thumbnails;

    return LayoutBuilder(
      builder: (context, constraints) {
        final autoColumns = resolveThumbnailGridColumnCount(
          width: constraints.maxWidth,
          spacing: context.appSpacing.sm,
          targetWidth: context.appComponentTokens.movieThumbnailTargetWidth,
        );
        final resolvedColumns = state.usesAutoColumns
            ? autoColumns
            : (state.columns ?? autoColumns);
        if (state.usesAutoColumns && state.columns != autoColumns) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              controller.applyAutoColumns(autoColumns);
            }
          });
        }

        return Padding(
          padding: EdgeInsets.only(
            top: context.appSpacing.md,
            bottom: context.appSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                key: const Key('movie-detail-thumbnail-toolbar'),
                spacing: _MovieDetailThumbnailControlGroup.groupSpacing,
                runSpacing: context.appSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _MovieDetailThumbnailIntervalSelector(
                    keyPrefix: 'movie-detail-thumbnail',
                    options: _intervalOptions,
                    selectedIntervalSeconds: state.selectedIntervalSeconds,
                    onSelect: controller.setIntervalSeconds,
                  ),
                  _MovieDetailThumbnailColumnsSelector(
                    keyPrefix: 'movie-detail-thumbnail',
                    options: _columnOptions,
                    selectedColumns: resolvedColumns,
                    onSelect: controller.setColumns,
                  ),
                  if (onCreateClip != null)
                    AppIconButton(
                      key: const Key('movie-detail-thumbnail-clip-toggle'),
                      tooltip: state.clipSelectionMode ? '退出切片圈选' : '圈选切片',
                      isSelected: state.clipSelectionMode,
                      size: AppIconButtonSize.mini,
                      selectedIconColor: Theme.of(context).colorScheme.primary,
                      onPressed: controller.toggleClipSelectionMode,
                      icon: const Icon(Icons.content_cut_rounded),
                    ),
                ],
              ),
              if (state.clipSelectionMode) ...[
                SizedBox(height: context.appSpacing.sm),
                ClipSelectionStatusBar(
                  keyPrefix: 'movie-detail-thumbnail',
                  startSeconds: state.clipStartThumbnail?.offsetSeconds,
                  endSeconds: state.clipEndThumbnail?.offsetSeconds,
                  durationSeconds: state.clipSelectionDurationSeconds,
                  canCreate: state.canCreateClip,
                  onCreate: onCreateClip,
                  onClear: controller.clearClipSelection,
                ),
              ],
              SizedBox(height: context.appSpacing.md),
              Expanded(
                child: MovieMediaThumbnailGrid(
                  thumbnails: thumbnails,
                  isLoading: state.isLoading,
                  errorMessage: state.errorMessage,
                  columns: resolvedColumns,
                  activeIndex: state.activeIndex,
                  isScrollLocked: false,
                  onRetry: controller.retry,
                  onThumbnailMenuRequested: onThumbnailMenuRequested,
                  clipStartIndex: state.clipStartIndex,
                  clipEndIndex: state.clipEndIndex,
                  onThumbnailTap: (index) {
                    if (state.clipSelectionMode) {
                      controller.handleClipSelectionTap(index);
                      return;
                    }
                    controller.selectIndex(index);
                    showMoviePlotPreviewOverlay(
                      context: context,
                      plotImages: thumbnails
                          .map((item) => item.image)
                          .toList(growable: false),
                      initialIndex: index,
                      onRequestImageMenu: onThumbnailMenuRequested == null
                          ? null
                          : (menuContext, previewIndex, globalPosition) async {
                              onThumbnailMenuRequested!(
                                previewIndex,
                                globalPosition,
                              );
                            },
                      presentation: thumbnailPreviewPresentation,
                      thumbnailStripLayout:
                          MoviePlotPreviewThumbnailStripLayout.fixed,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MovieDetailThumbnailIntervalSelector extends StatelessWidget {
  const _MovieDetailThumbnailIntervalSelector({
    required this.keyPrefix,
    required this.options,
    required this.selectedIntervalSeconds,
    required this.onSelect,
  });

  final String keyPrefix;
  final List<int> options;
  final int selectedIntervalSeconds;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return _MovieDetailThumbnailControlGroup(
      key: Key('$keyPrefix-interval-group'),
      iconKey: Key('$keyPrefix-interval-icon'),
      icon: Icons.schedule_rounded,
      tooltip: '缩略图时间间隔',
      children: [
        for (final seconds in options)
          AppTextButton(
            key: Key('$keyPrefix-interval-$seconds'),
            label: '$seconds',
            size: AppTextButtonSize.xSmall,
            isSelected: selectedIntervalSeconds == seconds,
            onPressed: () => onSelect(seconds),
          ),
      ],
    );
  }
}

class _MovieDetailThumbnailColumnsSelector extends StatelessWidget {
  const _MovieDetailThumbnailColumnsSelector({
    required this.keyPrefix,
    required this.options,
    required this.selectedColumns,
    required this.onSelect,
  });

  final String keyPrefix;
  final List<int> options;
  final int selectedColumns;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return _MovieDetailThumbnailControlGroup(
      key: Key('$keyPrefix-columns-group'),
      iconKey: Key('$keyPrefix-columns-icon'),
      icon: Icons.grid_view_rounded,
      tooltip: '缩略图列数',
      children: [
        for (final columns in options)
          AppTextButton(
            key: Key('$keyPrefix-columns-$columns'),
            label: '$columns',
            size: AppTextButtonSize.xSmall,
            isSelected: selectedColumns == columns,
            onPressed: () => onSelect(columns),
          ),
      ],
    );
  }
}

class _MovieDetailThumbnailControlGroup extends StatelessWidget {
  static const double groupSpacing = 12;
  static const double itemExtent = 28;

  const _MovieDetailThumbnailControlGroup({
    super.key,
    required this.icon,
    required this.iconKey,
    required this.tooltip,
    required this.children,
  });

  final IconData icon;
  final Key iconKey;
  final String tooltip;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Wrap(
      spacing: context.appSpacing.xs,
      runSpacing: context.appSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Tooltip(
          message: tooltip,
          child: SizedBox.square(
            key: iconKey,
            dimension: itemExtent,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceCard,
                borderRadius: context.appRadius.smBorder,
                border: Border.all(color: colors.borderStrong),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: context.appComponentTokens.iconSizeXs,
                  color: context.appTextPalette.primary,
                ),
              ),
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}
