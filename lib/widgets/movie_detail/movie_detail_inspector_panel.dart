import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/media/image_save_service.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/downloads/data/download_candidate_dto.dart';
import 'package:sakuramedia/features/downloads/data/download_request_dto.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/data/media_point_dto.dart';
import 'package:sakuramedia/features/movies/data/missav_thumbnail_stream_update.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_review_dto.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_missav_thumbnail_controller.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_magnet_controller.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_review_controller.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_thumbnail_controller.dart';
import 'package:sakuramedia/features/search/presentation/catalog_search_stream_status.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/media/app_image_action_menu.dart';
import 'package:sakuramedia/widgets/media/thumbnail_grid_column_resolver.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_plot_preview_overlay.dart';
import 'package:sakuramedia/widgets/movie_player/movie_media_thumbnail_grid.dart';
import 'package:sakuramedia/widgets/navigation/app_tab_bar.dart';
import 'package:sakuramedia/widgets/search/catalog_search_stream_status_card.dart';

class MovieDetailInspectorPanel extends StatefulWidget {
  const MovieDetailInspectorPanel({
    super.key,
    required this.movieNumber,
    required this.selectedMedia,
    required this.fetchMovieReviews,
    required this.fetchMediaThumbnails,
    required this.fetchMissavThumbnailsStream,
    required this.searchCandidates,
    required this.createDownloadRequest,
    required this.onClose,
    this.showCloseButton = true,
    this.thumbnailPreviewPresentation = MoviePlotPreviewPresentation.dialog,
    this.onSearchSimilar,
    this.onPlay,
  });

  final String movieNumber;
  final MovieMediaItemDto? selectedMedia;
  final Future<List<MovieReviewDto>> Function({
    required String movieNumber,
    required int page,
    required int pageSize,
    required MovieReviewSort sort,
  })
  fetchMovieReviews;
  final Future<List<MovieMediaThumbnailDto>> Function({required int mediaId})
  fetchMediaThumbnails;
  final Stream<MissavThumbnailStreamUpdate> Function({
    required String movieNumber,
    bool refresh,
  })
  fetchMissavThumbnailsStream;
  final Future<List<DownloadCandidateDto>> Function({
    required String movieNumber,
    String? indexerKind,
  })
  searchCandidates;
  final Future<DownloadRequestResponseDto> Function({
    required String movieNumber,
    required int clientId,
    required DownloadCandidateDto candidate,
  })
  createDownloadRequest;
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
  State<MovieDetailInspectorPanel> createState() =>
      _MovieDetailInspectorPanelState();
}

class _MovieDetailInspectorPanelState extends State<MovieDetailInspectorPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final MovieDetailReviewController _reviewController;
  late final MovieDetailThumbnailController _thumbnailController;
  late final MovieDetailMissavThumbnailController _missavThumbnailController;
  late final MovieDetailMagnetController _magnetController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 0);
    _reviewController = MovieDetailReviewController(
      movieNumber: widget.movieNumber,
      fetchMovieReviews: widget.fetchMovieReviews,
      initialSort: MovieReviewSort.hotly,
    );
    _thumbnailController = MovieDetailThumbnailController(
      mediaId: widget.selectedMedia?.mediaId,
      fetchMediaThumbnails: widget.fetchMediaThumbnails,
    );
    _missavThumbnailController = MovieDetailMissavThumbnailController(
      movieNumber: widget.movieNumber,
      fetchMissavThumbnailsStream: widget.fetchMissavThumbnailsStream,
    );
    _magnetController = MovieDetailMagnetController(
      movieNumber: widget.movieNumber,
      searchCandidates: widget.searchCandidates,
      createDownloadRequest: widget.createDownloadRequest,
    );
    _reviewController.loadInitial();
    _thumbnailController.loadIfNeeded();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reviewController.dispose();
    _thumbnailController.dispose();
    _missavThumbnailController.dispose();
    _magnetController.dispose();
    super.dispose();
  }

  Future<void> _showThumbnailActions(int index, Offset globalPosition) async {
    if (index < 0 || index >= _thumbnailController.thumbnails.length) {
      return;
    }
    final thumbnail = _thumbnailController.thumbnails[index];
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
        icon:
            point == null
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
    final points = await context.read<MediaApi>().getMediaPoints(
      mediaId: thumbnail.mediaId,
    );
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
    final imageUrl =
        thumbnail.image.origin.trim().isNotEmpty
            ? thumbnail.image.origin
            : thumbnail.image.bestAvailableUrl;
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
        final result = await ImageSaveService(
          fetchBytes: context.read<ApiClient>().getBytes,
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
            await context.read<MediaApi>().createMediaPoint(
              mediaId: thumbnail.mediaId,
              thumbnailId: thumbnail.thumbnailId,
            );
            if (mounted) {
              showToast('已添加标记');
            }
          } else {
            await context.read<MediaApi>().deleteMediaPoint(
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
                  Tab(text: 'Missav缩略图'),
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
              AnimatedBuilder(
                animation: _reviewController,
                builder: (context, child) {
                  return _MovieDetailReviewTab(controller: _reviewController);
                },
              ),
              AnimatedBuilder(
                animation: _magnetController,
                builder: (context, child) {
                  return _MovieDetailMagnetTab(
                    movieNumber: widget.movieNumber,
                    controller: _magnetController,
                  );
                },
              ),
              AnimatedBuilder(
                animation: _thumbnailController,
                builder: (context, child) {
                  return _MovieDetailThumbnailTab(
                    controller: _thumbnailController,
                    thumbnailPreviewPresentation:
                        widget.thumbnailPreviewPresentation,
                    onThumbnailMenuRequested: _showThumbnailActions,
                  );
                },
              ),
              AnimatedBuilder(
                animation: _missavThumbnailController,
                builder: (context, child) {
                  return _MovieDetailMissavThumbnailTab(
                    controller: _missavThumbnailController,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MovieDetailReviewTab extends StatefulWidget {
  const _MovieDetailReviewTab({required this.controller});

  final MovieDetailReviewController controller;

  @override
  State<_MovieDetailReviewTab> createState() => _MovieDetailReviewTabState();
}

class _MovieDetailReviewTabState extends State<_MovieDetailReviewTab> {
  static const double _loadMoreExtentAfterThreshold = 200;
  late final ScrollController _scrollController;
  int _lastAutoLoadTriggerItemCount = -1;
  bool _isSortSwitchLoading = false;

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
    if (widget.controller.items.length == _lastAutoLoadTriggerItemCount) {
      return;
    }
    _lastAutoLoadTriggerItemCount = widget.controller.items.length;
    widget.controller.loadMore();
  }

  Future<void> _handleSortChange(MovieReviewSort sort) async {
    if (_isSortSwitchLoading ||
        widget.controller.isInitialLoading ||
        widget.controller.sort == sort) {
      return;
    }
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _lastAutoLoadTriggerItemCount = -1;
    setState(() {
      _isSortSwitchLoading = true;
    });
    try {
      await widget.controller.setSort(sort);
    } finally {
      if (mounted) {
        setState(() {
          _isSortSwitchLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
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
                  isSelected: controller.sort == sort,
                  onPressed:
                      _isSortSwitchLoading
                          ? null
                          : () => _handleSortChange(sort),
                ),
            ],
          ),
          SizedBox(height: context.appSpacing.sm),
          Expanded(child: _buildContent(context)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isSortSwitchLoading) {
      return const Center(child: _ReviewSortSwitchLoadingIndicator());
    }

    final controller = widget.controller;
    if (controller.isInitialLoading && controller.items.isEmpty) {
      return const _MovieDetailReviewLoadingList();
    }

    if (controller.initialErrorMessage != null && controller.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              controller.initialErrorMessage!,
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
              onPressed: controller.loadInitial,
            ),
          ],
        ),
      );
    }

    if (controller.items.isEmpty) {
      return const Center(child: AppEmptyState(message: '暂无评论'));
    }

    return ListView.separated(
      controller: _scrollController,
      key: const Key('movie-detail-review-list'),
      itemCount: controller.items.length + 1,
      separatorBuilder:
          (context, index) => SizedBox(height: context.appSpacing.sm),
      itemBuilder: (context, index) {
        if (index < controller.items.length) {
          return _MovieDetailReviewCard(review: controller.items[index]);
        }
        return _MovieDetailReviewFooter(controller: controller);
      },
    );
  }
}

class _ReviewSortSwitchLoadingIndicator extends StatelessWidget {
  const _ReviewSortSwitchLoadingIndicator();

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final useCupertino = switch (platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      TargetPlatform.android ||
      TargetPlatform.fuchsia ||
      TargetPlatform.linux ||
      TargetPlatform.windows => false,
    };

    return SizedBox(
      key: const Key('movie-detail-review-sort-switch-loading-indicator'),
      width: context.appComponentTokens.iconSizeLg,
      height: context.appComponentTokens.iconSizeLg,
      child:
          useCupertino
              ? const CupertinoActivityIndicator(
                key: Key('movie-detail-review-sort-switch-loading-spinner'),
              )
              : const CircularProgressIndicator(
                key: Key('movie-detail-review-sort-switch-loading-spinner'),
                strokeWidth: 2,
              ),
    );
  }
}

class _MovieDetailReviewCard extends StatelessWidget {
  const _MovieDetailReviewCard({required this.review});

  final MovieReviewDto review;

  @override
  Widget build(BuildContext context) {
    final reviewDate =
        review.createdAt == null
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
  const _MovieDetailReviewFooter({required this.controller});

  final MovieDetailReviewController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoadingMore) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.appSpacing.sm),
        child: Center(
          child: CircularProgressIndicator.adaptive(
            key: Key('movie-detail-review-load-more-progress'),
          ),
        ),
      );
    }

    if (controller.loadMoreErrorMessage != null) {
      return Column(
        key: const Key('movie-detail-review-load-more-error'),
        children: [
          Text(
            controller.loadMoreErrorMessage!,
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
            onPressed: controller.loadMore,
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
          separatorBuilder:
              (context, index) => SizedBox(height: context.appSpacing.sm),
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

class _MovieDetailMagnetTab extends StatelessWidget {
  static const double _sortToolbarBreakpoint = 320;

  const _MovieDetailMagnetTab({
    required this.movieNumber,
    required this.controller,
  });

  final String movieNumber;
  final MovieDetailMagnetController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompactToolbar = constraints.maxWidth < _sortToolbarBreakpoint;
        return Padding(
          padding: EdgeInsets.only(
            top: context.appSpacing.md,
            bottom: context.appSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCompactToolbar)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _buildSortActions(context, compact: true),
                    ),
                    SizedBox(height: context.appSpacing.sm),
                    _buildSearchAction(
                      context,
                      alignment: Alignment.centerRight,
                    ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSortActions(context),
                    SizedBox(width: context.appSpacing.md),
                    Expanded(
                      child: _buildSearchAction(
                        context,
                        alignment: Alignment.centerRight,
                      ),
                    ),
                  ],
                ),
              SizedBox(height: context.appSpacing.md),
              Expanded(child: _buildContent(context)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchAction(
    BuildContext context, {
    Alignment alignment = Alignment.centerLeft,
  }) {
    return Align(
      alignment: alignment,
      child: AppButton(
        size: AppButtonSize.xxSmall,
        key: const Key('movie-detail-magnet-search-button'),
        label: controller.isLoading ? '搜索中' : '搜索资源',
        isLoading: controller.isLoading,
        variant: AppButtonVariant.primary,
        onPressed: controller.isLoading ? null : controller.search,
      ),
    );
  }

  Widget _buildSortActions(BuildContext context, {bool compact = false}) {
    final nextDirectionLabel =
        controller.selectedSortDirection == MovieDetailMagnetSortDirection.desc
            ? '当前降序，点击切换为升序'
            : '当前升序，点击切换为降序';
    final selectWidth =
        compact
            ? context.appLayoutTokens.filterFieldWidthSm - context.appSpacing.xl
            : context.appLayoutTokens.filterFieldWidthSm;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: selectWidth,
          child: AppSelectField<MovieDetailMagnetSortField>(
            key: const Key('movie-detail-magnet-sort-field'),
            value: controller.selectedSortField,
            size: AppSelectFieldSize.mini,
            textStyle: resolveAppTextStyle(
              context,
              size: AppTextSize.s10,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
            items: MovieDetailMagnetSortField.values
                .map(
                  (value) => DropdownMenuItem<MovieDetailMagnetSortField>(
                    value: value,
                    child: Text(value.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              controller.setSortField(value);
            },
          ),
        ),
        SizedBox(width: context.appSpacing.sm),
        AppIconButton(
          key: const Key('movie-detail-magnet-sort-direction'),
          tooltip: nextDirectionLabel,
          semanticLabel: nextDirectionLabel,
          isSelected: true,
          size: AppIconButtonSize.mini,
          icon:
              controller.selectedSortDirection.isAscending
                  ? const Icon(Icons.arrow_upward_rounded)
                  : const Icon(Icons.arrow_downward_rounded),
          onPressed: controller.toggleSortDirection,
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final items = controller.sortedItems;

    if (controller.isLoading && items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator.adaptive(
          key: Key('movie-detail-magnet-loading-indicator'),
        ),
      );
    }

    if (controller.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              controller.errorMessage!,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
            SizedBox(height: context.appSpacing.md),
            AppButton(
              key: const Key('movie-detail-magnet-retry-button'),
              label: '重试',
              variant: AppButtonVariant.secondary,
              onPressed: controller.search,
            ),
          ],
        ),
      );
    }

    if (!controller.hasSearched) {
      return const Center(child: AppEmptyState(message: '搜索依赖配置管理中的下载器与索引器。'));
    }

    if (items.isEmpty) {
      return const Center(child: AppEmptyState(message: '没有找到可用资源'));
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder:
          (context, index) => SizedBox(height: context.appSpacing.md),
      itemBuilder: (context, index) {
        final item = items[index];
        return _MovieDetailMagnetCandidateCard(
          key: Key('movie-detail-magnet-candidate-$index'),
          candidate: item,
          isSubmitting: controller.submittingCandidateKey == item.submitKey,
          submitButtonKey: Key('movie-detail-magnet-submit-$index'),
          onSubmit:
              item.hasDownloadSource
                  ? () async {
                    try {
                      final response = await controller.submitCandidate(item);
                      if (!context.mounted) {
                        return;
                      }
                      showToast(
                        response.created
                            ? '已提交到 ${item.resolvedClientName}'
                            : '下载任务已存在',
                      );
                    } catch (error) {
                      if (!context.mounted) {
                        return;
                      }
                      showToast(apiErrorMessage(error, fallback: '提交下载失败'));
                    }
                  }
                  : null,
        );
      },
    );
  }
}

class _MovieDetailMagnetCandidateCard extends StatelessWidget {
  const _MovieDetailMagnetCandidateCard({
    super.key,
    required this.candidate,
    required this.isSubmitting,
    required this.submitButtonKey,
    required this.onSubmit,
  });

  final DownloadCandidateDto candidate;
  final bool isSubmitting;
  final Key submitButtonKey;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.appSpacing.lg),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            candidate.title,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: context.appSpacing.sm),
          Wrap(
            spacing: context.appSpacing.md,
            runSpacing: context.appSpacing.xs,
            children: [
              _MagnetMetaText(label: '索引器', value: candidate.indexerName),
              _MagnetMetaText(
                label: '类型',
                value: candidate.indexerKind.toUpperCase(),
              ),
              _MagnetMetaText(
                label: '下载器',
                value: candidate.resolvedClientName,
              ),
              _MagnetMetaText(label: '做种', value: '${candidate.seeders}'),
              _MagnetMetaText(
                label: '体积',
                value: _formatFileSize(candidate.sizeBytes),
              ),
            ],
          ),
          SizedBox(height: context.appSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  '下载器: ${candidate.resolvedClientName}',
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.secondary,
                  ),
                ),
              ),
              AppButton(
                key: submitButtonKey,
                size: AppButtonSize.xSmall,
                label: candidate.hasDownloadSource ? '提交下载' : '资源地址缺失',
                variant: AppButtonVariant.primary,
                isLoading: isSubmitting,
                onPressed: onSubmit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MagnetMetaText extends StatelessWidget {
  const _MagnetMetaText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s12,
        weight: AppTextWeight.regular,
        tone: AppTextTone.secondary,
      ),
    );
  }
}

class _MovieDetailThumbnailTab extends StatelessWidget {
  static const List<int> _intervalOptions = <int>[10, 20, 30, 60];
  static const List<int> _columnOptions = <int>[2, 3, 4, 5];

  const _MovieDetailThumbnailTab({
    required this.controller,
    required this.thumbnailPreviewPresentation,
    this.onThumbnailMenuRequested,
  });

  final MovieDetailThumbnailController controller;
  final MoviePlotPreviewPresentation thumbnailPreviewPresentation;
  final void Function(int index, Offset globalPosition)?
  onThumbnailMenuRequested;

  @override
  Widget build(BuildContext context) {
    final thumbnails = controller.thumbnails;

    return LayoutBuilder(
      builder: (context, constraints) {
        final autoColumns = resolveThumbnailGridColumnCount(
          width: constraints.maxWidth,
          spacing: context.appSpacing.sm,
          targetWidth: context.appComponentTokens.movieThumbnailTargetWidth,
        );
        final resolvedColumns =
            controller.usesAutoColumns
                ? autoColumns
                : (controller.columns ?? autoColumns);
        if (controller.usesAutoColumns && controller.columns != autoColumns) {
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
                children: [
                  _MovieDetailThumbnailIntervalSelector(
                    keyPrefix: 'movie-detail-thumbnail',
                    options: _intervalOptions,
                    selectedIntervalSeconds: controller.selectedIntervalSeconds,
                    onSelect: controller.setIntervalSeconds,
                  ),
                  _MovieDetailThumbnailColumnsSelector(
                    keyPrefix: 'movie-detail-thumbnail',
                    options: _columnOptions,
                    selectedColumns: resolvedColumns,
                    onSelect: controller.setColumns,
                  ),
                ],
              ),
              SizedBox(height: context.appSpacing.md),
              Expanded(
                child: MovieMediaThumbnailGrid(
                  thumbnails: thumbnails,
                  isLoading: controller.isLoading,
                  errorMessage: controller.errorMessage,
                  columns: resolvedColumns,
                  activeIndex: controller.activeIndex,
                  isScrollLocked: false,
                  onRetry: controller.retry,
                  onThumbnailMenuRequested: onThumbnailMenuRequested,
                  onThumbnailTap: (index) {
                    controller.selectIndex(index);
                    showMoviePlotPreviewOverlay(
                      context: context,
                      plotImages: thumbnails
                          .map((item) => item.image)
                          .toList(growable: false),
                      initialIndex: index,
                      onRequestImageMenu:
                          onThumbnailMenuRequested == null
                              ? null
                              : (
                                menuContext,
                                previewIndex,
                                globalPosition,
                              ) async {
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

class _MovieDetailMissavThumbnailTab extends StatelessWidget {
  static const List<int> _intervalOptions = <int>[10, 20, 30, 60];
  static const List<int> _columnOptions = <int>[2, 3, 4, 5];

  const _MovieDetailMissavThumbnailTab({required this.controller});

  final MovieDetailMissavThumbnailController controller;

  @override
  Widget build(BuildContext context) {
    final items = controller.items;
    final thumbnails = items
        .map(
          (item) => MovieMediaThumbnailDto(
            thumbnailId: item.index,
            mediaId: 0,
            offsetSeconds: 0,
            image: item.toMovieImage(),
          ),
        )
        .toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final autoColumns = resolveThumbnailGridColumnCount(
          width: constraints.maxWidth,
          spacing: context.appSpacing.sm,
          targetWidth: context.appComponentTokens.movieThumbnailTargetWidth,
        );
        final resolvedColumns =
            controller.usesAutoColumns
                ? autoColumns
                : (controller.columns ?? autoColumns);
        if (controller.usesAutoColumns && controller.columns != autoColumns) {
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
              _MovieDetailMissavTabHeader(
                state: controller.state,
                columns: resolvedColumns,
                selectedIntervalSeconds: controller.selectedIntervalSeconds,
                onSetInterval: controller.setIntervalSeconds,
                onStart: controller.load,
                onRetry: controller.load,
                onSetColumns: controller.setColumns,
              ),
              SizedBox(height: context.appSpacing.md),
              Expanded(
                child: _buildContent(
                  context: context,
                  thumbnails: thumbnails,
                  resolvedColumns: resolvedColumns,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required List<MovieMediaThumbnailDto> thumbnails,
    required int resolvedColumns,
  }) {
    switch (controller.state) {
      case MovieDetailMissavThumbnailState.idle:
        return _MovieDetailMissavHintState(
          message: '这是 MissAV 外部来源帧图，首次获取可能耗时较长。',
        );
      case MovieDetailMissavThumbnailState.loading:
        final status = controller.status;
        if (status == null) {
          return const SizedBox.shrink();
        }
        return _MovieDetailMissavLoadingState(status: status);
      case MovieDetailMissavThumbnailState.empty:
        return const Center(child: AppEmptyState(message: 'MissAV 暂无可展示缩略图'));
      case MovieDetailMissavThumbnailState.error:
        return Center(
          child: AppEmptyState(
            message: controller.errorMessage ?? 'MissAV 缩略图获取失败，请稍后重试。',
          ),
        );
      case MovieDetailMissavThumbnailState.success:
        return MovieMediaThumbnailGrid(
          thumbnails: thumbnails,
          isLoading: false,
          errorMessage: null,
          columns: resolvedColumns,
          activeIndex: controller.activeIndex,
          isScrollLocked: false,
          onRetry: controller.load,
          keyPrefix: 'movie-detail-missav',
          onThumbnailTap: controller.selectIndex,
        );
    }
  }
}

class _MovieDetailMissavTabHeader extends StatelessWidget {
  const _MovieDetailMissavTabHeader({
    required this.state,
    required this.columns,
    required this.selectedIntervalSeconds,
    required this.onSetInterval,
    required this.onStart,
    required this.onRetry,
    required this.onSetColumns,
  });

  final MovieDetailMissavThumbnailState state;
  final int columns;
  final int selectedIntervalSeconds;
  final ValueChanged<int> onSetInterval;
  final VoidCallback onStart;
  final VoidCallback onRetry;
  final ValueChanged<int> onSetColumns;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('movie-detail-missav-toolbar'),
      spacing: _MovieDetailThumbnailControlGroup.groupSpacing,
      runSpacing: context.appSpacing.xs,
      children: [
        _MovieDetailThumbnailIntervalSelector(
          keyPrefix: 'movie-detail-missav',
          options: _MovieDetailMissavThumbnailTab._intervalOptions,
          selectedIntervalSeconds: selectedIntervalSeconds,
          onSelect: onSetInterval,
        ),
        switch (state) {
          MovieDetailMissavThumbnailState.idle => AppButton(
            key: const Key('movie-detail-missav-start-button'),
            label: '开始获取',
            size: AppButtonSize.xSmall,
            variant: AppButtonVariant.primary,
            onPressed: onStart,
          ),
          MovieDetailMissavThumbnailState.error => AppButton(
            key: const Key('movie-detail-missav-retry-button'),
            label: '重新获取',
            size: AppButtonSize.xSmall,
            variant: AppButtonVariant.secondary,
            onPressed: onRetry,
          ),
          MovieDetailMissavThumbnailState.success => Wrap(
            children: [
              _MovieDetailThumbnailColumnsSelector(
                keyPrefix: 'movie-detail-missav',
                options: _MovieDetailMissavThumbnailTab._columnOptions,
                selectedColumns: columns,
                onSelect: onSetColumns,
              ),
            ],
          ),
          MovieDetailMissavThumbnailState.loading ||
          MovieDetailMissavThumbnailState.empty => const SizedBox.shrink(),
        },
      ],
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

class _MovieDetailMissavHintState extends StatelessWidget {
  const _MovieDetailMissavHintState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
      ),
    );
  }
}

class _MovieDetailMissavLoadingState extends StatelessWidget {
  const _MovieDetailMissavLoadingState({required this.status});

  final CatalogSearchStreamStatus status;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        key: const Key('movie-detail-missav-loading-state'),
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [CatalogSearchStreamStatusCard(status: status)],
        ),
      ),
    );
  }
}

String _formatFileSize(int bytes) {
  if (bytes <= 0) {
    return '0 MB';
  }
  const bytesPerGb = 1024 * 1024 * 1024;
  const bytesPerMb = 1024 * 1024;
  if (bytes >= bytesPerGb) {
    return '${(bytes / bytesPerGb).toStringAsFixed(1)} GB';
  }
  return '${(bytes / bytesPerMb).toStringAsFixed(1)} MB';
}
