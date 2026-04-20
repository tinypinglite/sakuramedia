import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/core/media/image_save_service.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/data/media_point_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actors/actor_avatar.dart';
import 'package:sakuramedia/widgets/media/media_preview_action_grid.dart';
import 'package:sakuramedia/widgets/media/preview_dialog_surface.dart';
import 'package:sakuramedia/widgets/media/preview_image_stage.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_plot_thumbnail.dart';

class MediaPreviewItem {
  const MediaPreviewItem({
    required this.imageUrl,
    required this.fileName,
    required this.mediaId,
    required this.movieNumber,
    required this.thumbnailId,
    required this.offsetSeconds,
    this.scoreText,
  });

  final String imageUrl;
  final String fileName;
  final int mediaId;
  final String movieNumber;
  final int thumbnailId;
  final int offsetSeconds;
  final String? scoreText;
}

enum MediaPreviewPresentation { dialog, bottomDrawer }

class MediaPreviewDialog extends StatefulWidget {
  const MediaPreviewDialog({
    super.key,
    required this.item,
    this.onSearchSimilar,
    this.onPlay,
    this.onOpenMovieDetail,
    this.onPointRemoved,
    this.closeOnPointRemoved = false,
    this.presentation = MediaPreviewPresentation.dialog,
  });

  final MediaPreviewItem item;
  final Future<bool> Function()? onSearchSimilar;
  final VoidCallback? onPlay;
  final VoidCallback? onOpenMovieDetail;
  final VoidCallback? onPointRemoved;
  final bool closeOnPointRemoved;
  final MediaPreviewPresentation presentation;

  @override
  State<MediaPreviewDialog> createState() => _MediaPreviewDialogState();
}

class _MediaPreviewDialogState extends State<MediaPreviewDialog> {
  final ScrollController _actorScrollController = ScrollController();
  MovieDetailDto? _movieDetail;
  List<MediaPointDto> _mediaPoints = const <MediaPointDto>[];
  bool _isLoadingMovieDetail = true;
  bool _isLoadingMediaPoints = true;
  bool _isSavingImage = false;
  bool _isTogglingPoint = false;
  bool _isSearchingSimilar = false;
  String? _movieDetailErrorMessage;
  String? _mediaPointsErrorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _actorScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait(<Future<void>>[_loadMovieDetail(), _loadMediaPoints()]);
  }

  Future<void> _loadMovieDetail() async {
    setState(() {
      _isLoadingMovieDetail = true;
      _movieDetailErrorMessage = null;
    });
    try {
      final movieDetail = await context.read<MoviesApi>().getMovieDetail(
        movieNumber: widget.item.movieNumber,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _movieDetail = movieDetail;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _movieDetailErrorMessage = apiErrorMessage(error, fallback: '影片详情加载失败');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMovieDetail = false;
        });
      }
    }
  }

  Future<void> _loadMediaPoints() async {
    if (widget.item.mediaId <= 0) {
      setState(() {
        _isLoadingMediaPoints = false;
        _mediaPointsErrorMessage = '当前结果缺少媒体标识';
      });
      return;
    }

    setState(() {
      _isLoadingMediaPoints = true;
      _mediaPointsErrorMessage = null;
    });
    try {
      final points = await context.read<MediaApi>().getMediaPoints(
        mediaId: widget.item.mediaId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _mediaPoints = points;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _mediaPointsErrorMessage = apiErrorMessage(error, fallback: '标记信息加载失败');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMediaPoints = false;
        });
      }
    }
  }

  MediaPointDto? get _existingPoint {
    for (final point in _mediaPoints) {
      if (point.thumbnailId == widget.item.thumbnailId) {
        return point;
      }
    }
    return null;
  }

  bool get _canTogglePoint =>
      widget.item.mediaId > 0 &&
      widget.item.thumbnailId > 0 &&
      !_isLoadingMediaPoints &&
      _mediaPointsErrorMessage == null;

  @override
  Widget build(BuildContext context) {
    if (widget.presentation == MediaPreviewPresentation.bottomDrawer) {
      final screenHeight = MediaQuery.sizeOf(context).height;
      final previewHeight = math.min(
        320.0,
        math.max(220.0, screenHeight * 0.32),
      );
      return _buildPreviewContent(context, previewHeight: previewHeight);
    }

    final spacing = context.appSpacing;
    final insetPadding = EdgeInsets.symmetric(
      horizontal: spacing.xxxl,
      vertical: spacing.xxl,
    );
    final dialogHeight = math.min(
      context.appComponentTokens.movieDetailDialogMinHeight,
      math.max(0.0, MediaQuery.sizeOf(context).height - insetPadding.vertical),
    );
    final previewHeight = dialogHeight * 0.5;

    return PreviewDialogSurface(
      dialogKey: const Key('image-search-result-preview-dialog'),
      contentKey: const Key('image-search-result-preview-dialog-content'),
      insetPadding: insetPadding,
      width: context.appComponentTokens.movieDetailDialogWidth,
      height: dialogHeight,
      child: _buildPreviewContent(context, previewHeight: previewHeight),
    );
  }

  Widget _buildPreviewContent(
    BuildContext context, {
    required double previewHeight,
  }) {
    final spacing = context.appSpacing;
    final movieInfoSection = _buildMovieInfoSection(context);
    final actionsSection = MediaPreviewActionGrid(
      key: const Key('image-search-result-preview-actions'),
      layout: MediaPreviewActionGridLayout.horizontalScroll,
      spacing: spacing.xs,
      tileWidth: 64,
      actions: [
        MediaPreviewActionItem(
          label: '相似图片',
          icon: Icons.image_search_outlined,
          isLoading: _isSearchingSimilar,
          onTap: widget.onSearchSimilar == null ? null : _handleSearchSimilar,
        ),
        MediaPreviewActionItem(
          label: '保存',
          icon: Icons.download_outlined,
          isLoading: _isSavingImage,
          onTap: _handleSaveToLocal,
        ),
        MediaPreviewActionItem(
          label: _existingPoint == null ? '添加标记' : '删除标记',
          icon:
              _existingPoint == null
                  ? Icons.bookmark_add_outlined
                  : Icons.bookmark_remove_outlined,
          isLoading: _isTogglingPoint,
          onTap: _canTogglePoint ? _handleTogglePoint : null,
        ),
        MediaPreviewActionItem(
          label: '播放',
          icon: Icons.play_circle_outline_rounded,
          visible: widget.item.mediaId > 0,
          onTap:
              widget.item.mediaId > 0 && widget.onPlay != null
                  ? _handlePlay
                  : null,
        ),
        MediaPreviewActionItem(
          label: '影片详情',
          icon: Icons.info_outline_rounded,
          visible: widget.onOpenMovieDetail != null,
          onTap:
              widget.onOpenMovieDetail == null ? null : _handleOpenMovieDetail,
        ),
      ],
    );

    if (widget.presentation == MediaPreviewPresentation.bottomDrawer) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final maxPreviewHeight = math.max(
            140.0,
            constraints.maxHeight * 0.34,
          );
          final resolvedPreviewHeight = math.min(
            previewHeight,
            maxPreviewHeight,
          );
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PreviewImageStage(
                  stageKey: const Key('image-search-result-preview-hero'),
                  imageUrl: widget.item.imageUrl,
                  height: resolvedPreviewHeight,
                  onClose: () => Navigator.of(context).pop(),
                  showCloseButton: false,
                ),
                Container(
                  key: const Key('image-search-result-preview-summary'),
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    // horizontal: spacing.lg,
                    vertical: spacing.sm,
                  ),
                  // color: context.appColors.surfaceMuted,
                  child: Text(
                    _summaryText,
                    textAlign: TextAlign.center,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      weight: AppTextWeight.regular,
                      tone: AppTextTone.muted,
                    ),
                  ),
                ),
                movieInfoSection,
                SizedBox(height: context.appSpacing.sm),
                // Divider(height: 1, color: context.appColors.borderSubtle),
                actionsSection,
              ],
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PreviewImageStage(
          stageKey: const Key('image-search-result-preview-hero'),
          imageUrl: widget.item.imageUrl,
          height: previewHeight,
          onClose: () => Navigator.of(context).pop(),
          showCloseButton: false,
        ),
        Container(
          key: const Key('image-search-result-preview-summary'),
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: spacing.lg,
            vertical: spacing.sm,
          ),
          color: context.appColors.surfaceMuted,
          child: Text(
            _summaryText,
            textAlign: TextAlign.center,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
        ),
        Expanded(child: movieInfoSection),
        // Divider(height: 1, color: context.appColors.borderSubtle),
        actionsSection,
      ],
    );
  }

  String get _summaryText {
    final scoreText = widget.item.scoreText;
    final fragments = <String>[];
    if (scoreText != null && scoreText.isNotEmpty) {
      fragments.add('相似度 $scoreText');
    }
    fragments.add('番号 ${widget.item.movieNumber}');
    fragments.add('时间点 ${formatMediaTimecode(widget.item.offsetSeconds)}');
    return fragments.join(' | ');
  }

  Widget _buildMovieInfoSection(BuildContext context) {
    final spacing = context.appSpacing;
    if (_isLoadingMovieDetail) {
      return const SizedBox(
        height: 132,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_movieDetailErrorMessage != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _movieDetailErrorMessage!,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(height: spacing.md),
          TextButton(onPressed: _loadMovieDetail, child: const Text('重试')),
        ],
      );
    }

    final movie = _movieDetail;
    if (movie == null) {
      return const SizedBox.shrink();
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          key: const Key('image-search-result-preview-movie-cover'),
          child:
              movie.coverImage == null
                  ? ClipRRect(
                    borderRadius: context.appRadius.mdBorder,
                    child: SizedBox(
                      width: 88,
                      height: 80,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: context.appColors.surfaceMuted,
                        ),
                        child: const Center(child: Icon(Icons.movie_outlined)),
                      ),
                    ),
                  )
                  : MoviePlotThumbnail(
                    url: movie.coverImage!.bestAvailableUrl,
                    maxHeight: 80,
                    fit: BoxFit.cover,
                    borderRadius: context.appRadius.mdBorder,
                    fallbackAspectRatio: 0.72,
                  ),
        ),
        SizedBox(width: spacing.sm),
        Expanded(
          child:
              movie.actors.isEmpty
                  ? Text(
                    movie.title,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s18,
                      weight: AppTextWeight.semibold,
                      tone: AppTextTone.primary,
                    ),
                  )
                  : _MovieActorStrip(
                    actors: movie.actors,
                    controller: _actorScrollController,
                  ),
        ),
      ],
    );
  }

  Future<void> _handleSearchSimilar() async {
    if (_isSearchingSimilar || widget.onSearchSimilar == null) {
      return;
    }
    setState(() => _isSearchingSimilar = true);
    final success = await widget.onSearchSimilar!.call();
    if (!mounted) {
      return;
    }
    setState(() => _isSearchingSimilar = false);
    if (success) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleSaveToLocal() async {
    if (_isSavingImage) {
      return;
    }
    setState(() => _isSavingImage = true);
    try {
      final result = await ImageSaveService(
        fetchBytes: context.read<ApiClient>().getBytes,
      ).saveImageFromUrl(
        imageUrl: widget.item.imageUrl,
        fileName: widget.item.fileName,
        dialogTitle: '保存到本地',
      );
      if (mounted && result.status == ImageSaveStatus.success) {
        showToast(result.message ?? '图片已保存');
      }
      if (mounted && result.status == ImageSaveStatus.failed) {
        showToast(result.message ?? '保存图片失败');
      }
    } catch (error) {
      if (mounted) {
        showToast(apiErrorMessage(error, fallback: '保存图片失败'));
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingImage = false);
      }
    }
  }

  Future<void> _handleTogglePoint() async {
    if (_isTogglingPoint || !_canTogglePoint) {
      return;
    }
    setState(() => _isTogglingPoint = true);
    try {
      final existingPoint = _existingPoint;
      if (existingPoint == null) {
        final point = await context.read<MediaApi>().createMediaPoint(
          mediaId: widget.item.mediaId,
          thumbnailId: widget.item.thumbnailId,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _mediaPoints = <MediaPointDto>[..._mediaPoints, point];
        });
        showToast('已添加标记');
      } else {
        await context.read<MediaApi>().deleteMediaPoint(
          mediaId: widget.item.mediaId,
          pointId: existingPoint.pointId,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _mediaPoints = _mediaPoints
              .where((point) => point.pointId != existingPoint.pointId)
              .toList(growable: false);
        });
        widget.onPointRemoved?.call();
        showToast('已删除标记');
        if (widget.closeOnPointRemoved) {
          Navigator.of(context).pop();
        }
      }
    } catch (error) {
      if (mounted) {
        showToast(apiErrorMessage(error, fallback: '更新标记失败'));
      }
    } finally {
      if (mounted) {
        setState(() => _isTogglingPoint = false);
      }
    }
  }

  void _handlePlay() {
    debugPrint(
      '[player-debug] preview_play_tap movie=${widget.item.movieNumber} mediaId=${widget.item.mediaId} offsetSeconds=${widget.item.offsetSeconds} presentation=${widget.presentation.name}',
    );
    widget.onPlay?.call();
    Navigator.of(context).pop();
  }

  void _handleOpenMovieDetail() {
    widget.onOpenMovieDetail?.call();
    Navigator.of(context).pop();
  }
}

class _MovieActorStrip extends StatelessWidget {
  const _MovieActorStrip({required this.actors, required this.controller});

  final List<MovieActorDto> actors;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final tokens = context.appComponentTokens;
    final itemHeight =
        tokens.movieDetailActorAvatarSize +
        spacing.xs +
        spacing.lg +
        spacing.sm;

    return SizedBox(
      key: const Key('image-search-result-preview-actor-strip'),
      height: itemHeight,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ListView.separated(
          key: const Key('image-search-result-preview-actor-list'),
          controller: controller,
          scrollDirection: Axis.horizontal,
          primary: false,
          itemCount: actors.length,
          separatorBuilder: (_, __) => SizedBox(width: spacing.sm),
          itemBuilder: (context, index) {
            final actor = actors[index];
            final tooltip =
                actor.aliasName.isEmpty ? actor.name : actor.aliasName;
            final itemKey =
                actor.id > 0
                    ? Key('image-search-result-preview-actor-${actor.id}')
                    : Key('image-search-result-preview-actor-index-$index');

            return Tooltip(
              message: tooltip,
              child: KeyedSubtree(
                key: itemKey,
                child: SizedBox(
                  // width: tokens.movieDetailActorCardWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ActorAvatar(
                        imageUrl: actor.profileImage?.bestAvailableUrl,
                        size: tokens.movieDetailActorAvatarSize,
                      ),
                      SizedBox(height: spacing.sm),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: tokens.movieDetailActorCardWidth,
                        ),
                        child: Text(
                          actor.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: resolveAppTextStyle(
                            context,
                            size: AppTextSize.s12,
                            tone: AppTextTone.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
