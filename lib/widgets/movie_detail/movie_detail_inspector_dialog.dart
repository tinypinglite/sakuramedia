import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/media/image_save_service.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/downloads/data/download_candidate_dto.dart';
import 'package:sakuramedia/features/downloads/data/download_request_dto.dart';
import 'package:sakuramedia/features/downloads/data/downloads_api.dart';
import 'package:sakuramedia/features/image_search/presentation/desktop_image_search_launcher.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/data/media_point_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_magnet_controller.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_thumbnail_controller.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/media/app_image_action_menu.dart';
import 'package:sakuramedia/widgets/media/thumbnail_grid_column_resolver.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_detail_pill_wrap.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_plot_preview_overlay.dart';
import 'package:sakuramedia/widgets/movie_player/movie_media_thumbnail_grid.dart';
import 'package:sakuramedia/widgets/navigation/app_tab_bar.dart';

Future<void> showMovieDetailInspectorDialog({
  required BuildContext context,
  required String movieNumber,
  required MovieMediaItemDto? selectedMedia,
}) {
  return showDialog<void>(
    context: context,
    builder:
        (dialogContext) => MovieDetailInspectorDialog(
          hostContext: context,
          movieNumber: movieNumber,
          selectedMedia: selectedMedia,
          fetchMediaThumbnails:
              dialogContext.read<MoviesApi>().getMediaThumbnails,
          searchCandidates: dialogContext.read<DownloadsApi>().searchCandidates,
          createDownloadRequest:
              dialogContext.read<DownloadsApi>().createDownloadRequest,
        ),
  );
}

class MovieDetailInspectorDialog extends StatefulWidget {
  const MovieDetailInspectorDialog({
    super.key,
    required this.hostContext,
    required this.movieNumber,
    required this.selectedMedia,
    required this.fetchMediaThumbnails,
    required this.searchCandidates,
    required this.createDownloadRequest,
  });

  final BuildContext hostContext;
  final String movieNumber;
  final MovieMediaItemDto? selectedMedia;
  final Future<List<MovieMediaThumbnailDto>> Function({required int mediaId})
  fetchMediaThumbnails;
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

  @override
  State<MovieDetailInspectorDialog> createState() =>
      _MovieDetailInspectorDialogState();
}

class _MovieDetailInspectorDialogState extends State<MovieDetailInspectorDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final MovieDetailThumbnailController _thumbnailController;
  late final MovieDetailMagnetController _magnetController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
    _thumbnailController = MovieDetailThumbnailController(
      mediaId: widget.selectedMedia?.mediaId,
      fetchMediaThumbnails: widget.fetchMediaThumbnails,
    );
    _magnetController = MovieDetailMagnetController(
      movieNumber: widget.movieNumber,
      searchCandidates: widget.searchCandidates,
      createDownloadRequest: widget.createDownloadRequest,
    );
    _thumbnailController.loadIfNeeded();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _thumbnailController.dispose();
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
      const AppImageActionDescriptor(
        type: AppImageActionType.searchSimilar,
        label: '相似图片',
        icon: Icons.image_search_outlined,
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
        enabled: hasMedia,
      ),
    ];
  }

  Future<MediaPointDto?> _loadMatchingPoint(
    MovieMediaThumbnailDto thumbnail,
  ) async {
    if (thumbnail.mediaId <= 0) {
      return null;
    }
    final points = await context.read<MediaApi>().getMediaPoints(
      mediaId: thumbnail.mediaId,
    );
    for (final point in points) {
      if (point.offsetSeconds == thumbnail.offsetSeconds) {
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
        Navigator.of(context).pop();
        Future<void>.microtask(() async {
          if (!widget.hostContext.mounted) {
            return;
          }
          await launchDesktopImageSearchFromUrl(
            widget.hostContext,
            imageUrl: imageUrl,
            fallbackPath:
                '${desktopMoviesPath}/${Uri.encodeComponent(widget.movieNumber)}',
            fileName: fileName,
            replaceCurrent: true,
          );
        });
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
        if (thumbnail.mediaId <= 0) {
          return;
        }
        try {
          if (point == null) {
            await context.read<MediaApi>().createMediaPoint(
              mediaId: thumbnail.mediaId,
              offsetSeconds: thumbnail.offsetSeconds,
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
        Navigator.of(context).pop();
        Future<void>.microtask(() {
          if (!widget.hostContext.mounted) {
            return;
          }
          widget.hostContext.go(
            buildDesktopMoviePlayerRoutePath(
              widget.movieNumber,
              mediaId: thumbnail.mediaId > 0 ? thumbnail.mediaId : null,
              positionSeconds: thumbnail.offsetSeconds,
            ),
          );
        });
        break;
      case AppImageActionType.movieDetail:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const Key('movie-detail-inspector-dialog'),
      insetPadding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.xxxl,
        vertical: context.appSpacing.xxl,
      ),
      child: SizedBox(
        width: context.appComponentTokens.movieDetailDialogWidth,
        height: context.appComponentTokens.movieDetailDialogMinHeight,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.appSpacing.lg,
                context.appSpacing.md,
                context.appSpacing.sm,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppTabBar(
                      controller: _tabController,
                      tabs: const <Widget>[Tab(text: '磁力搜索'), Tab(text: '缩略图')],
                    ),
                  ),
                  AppIconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
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
                        onThumbnailMenuRequested: _showThumbnailActions,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovieDetailMagnetTab extends StatelessWidget {
  const _MovieDetailMagnetTab({
    required this.movieNumber,
    required this.controller,
  });

  final String movieNumber;
  final MovieDetailMagnetController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.appSpacing.lg,
        context.appSpacing.md,
        context.appSpacing.lg,
        context.appSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: context.appSpacing.sm,
            runSpacing: context.appSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final kind in MovieDetailMagnetIndexerKind.values)
                AppButton(
                  key: Key(
                    'movie-detail-magnet-filter-${kind == MovieDetailMagnetIndexerKind.all ? 'all' : kind.apiValue}',
                  ),
                  label: kind.label,
                  size: AppButtonSize.xSmall,
                  variant: AppButtonVariant.secondary,
                  isSelected: controller.selectedIndexerKind == kind,
                  onPressed: () => controller.setIndexerKind(kind),
                ),
              AppButton(
                size: AppButtonSize.xSmall,
                key: const Key('movie-detail-magnet-search-button'),
                label: controller.isLoading ? '搜索中' : '搜索资源',
                isLoading: controller.isLoading,
                variant: AppButtonVariant.primary,
                onPressed: controller.isLoading ? null : controller.search,
              )
             
            ],
          ),
          SizedBox(height: context.appSpacing.md),
          Expanded(child: _buildContent(context)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (controller.isLoading && controller.items.isEmpty) {
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.appColors.textSecondary,
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

    if (controller.items.isEmpty) {
      return const Center(child: AppEmptyState(message: '没有找到可用资源'));
    }

    return ListView.separated(
      itemCount: controller.items.length,
      separatorBuilder:
          (context, index) => SizedBox(height: context.appSpacing.md),
      itemBuilder: (context, index) {
        final item = controller.items[index];
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
          Text(candidate.title, style: Theme.of(context).textTheme.bodyMedium),
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.appColors.textSecondary,
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
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: context.appColors.textSecondary),
    );
  }
}

class _MovieDetailThumbnailTab extends StatelessWidget {
  const _MovieDetailThumbnailTab({
    required this.controller,
    this.onThumbnailMenuRequested,
  });

  final MovieDetailThumbnailController controller;
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
          padding: EdgeInsets.fromLTRB(
            context.appSpacing.lg,
            context.appSpacing.md,
            context.appSpacing.lg,
            context.appSpacing.lg,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '缩略图',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  for (final count in const <int>[2, 3, 4, 5]) ...[
                    if (count != 2) SizedBox(width: context.appSpacing.xs),
                    AppButton(
                      key: Key('movie-detail-thumbnail-columns-$count'),
                      label: '$count',
                      size: AppButtonSize.xSmall,
                      variant: AppButtonVariant.secondary,
                      isSelected: resolvedColumns == count,
                      onPressed: () => controller.setColumns(count),
                    ),
                  ],
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
