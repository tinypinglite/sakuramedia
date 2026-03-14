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
import 'package:sakuramedia/widgets/media/masked_image.dart';
import 'package:sakuramedia/widgets/media/preview_dialog_surface.dart';
import 'package:sakuramedia/widgets/media/preview_image_stage.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_plot_thumbnail.dart';

class MediaPreviewItem {
  const MediaPreviewItem({
    required this.imageUrl,
    required this.fileName,
    required this.mediaId,
    required this.movieNumber,
    required this.offsetSeconds,
    this.scoreText,
  });

  final String imageUrl;
  final String fileName;
  final int mediaId;
  final String movieNumber;
  final int offsetSeconds;
  final String? scoreText;
}

class MediaPreviewDialog extends StatefulWidget {
  const MediaPreviewDialog({
    super.key,
    required this.item,
    this.onSearchSimilar,
    this.onPlay,
    this.onOpenMovieDetail,
    this.onPointRemoved,
    this.closeOnPointRemoved = false,
  });

  final MediaPreviewItem item;
  final Future<bool> Function()? onSearchSimilar;
  final VoidCallback? onPlay;
  final VoidCallback? onOpenMovieDetail;
  final VoidCallback? onPointRemoved;
  final bool closeOnPointRemoved;

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
      if (point.offsetSeconds == widget.item.offsetSeconds) {
        return point;
      }
    }
    return null;
  }

  bool get _canTogglePoint =>
      widget.item.mediaId > 0 &&
      !_isLoadingMediaPoints &&
      _mediaPointsErrorMessage == null;

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PreviewImageStage(
            stageKey: const Key('image-search-result-preview-hero'),
            imageUrl: widget.item.imageUrl,
            height: previewHeight,
            onClose: () => Navigator.of(context).pop(),
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
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(spacing.lg),
              child: _buildMovieInfoSection(context),
            ),
          ),
          Divider(height: 1, color: context.appColors.borderSubtle),
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.lg,
              spacing.md,
              spacing.lg,
              spacing.lg,
            ),
            child: Wrap(
              key: const Key('image-search-result-preview-actions'),
              alignment: WrapAlignment.start,
              runAlignment: WrapAlignment.start,
              spacing: spacing.md,
              runSpacing: spacing.md,
              children: [
                _PreviewActionTile(
                  label: '相似图片',
                  icon: Icons.image_search_outlined,
                  isLoading: _isSearchingSimilar,
                  onTap:
                      widget.onSearchSimilar == null
                          ? null
                          : _handleSearchSimilar,
                ),
                _PreviewActionTile(
                  label: '保存到本地',
                  icon: Icons.download_outlined,
                  isLoading: _isSavingImage,
                  onTap: _handleSaveToLocal,
                ),
                _PreviewActionTile(
                  label: _existingPoint == null ? '添加标记' : '删除标记',
                  icon:
                      _existingPoint == null
                          ? Icons.bookmark_add_outlined
                          : Icons.bookmark_remove_outlined,
                  isLoading: _isTogglingPoint,
                  onTap: _canTogglePoint ? _handleTogglePoint : null,
                ),
                _PreviewActionTile(
                  label: '播放',
                  icon: Icons.play_circle_outline_rounded,
                  onTap:
                      widget.item.mediaId > 0 && widget.onPlay != null
                          ? _handlePlay
                          : null,
                ),
                _PreviewActionTile(
                  label: '影片详情',
                  icon: Icons.info_outline_rounded,
                  onTap:
                      widget.onOpenMovieDetail == null
                          ? null
                          : _handleOpenMovieDetail,
                ),
              ],
            ),
          ),
        ],
      ),
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
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.appColors.textMuted),
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
                      height: 116,
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
                    maxHeight: 116,
                    fit: BoxFit.cover,
                    borderRadius: context.appRadius.mdBorder,
                    fallbackAspectRatio: 0.72,
                  ),
        ),
        SizedBox(width: spacing.lg),
        Expanded(
          child:
              movie.actors.isEmpty
                  ? Text(
                    movie.title,
                    style: Theme.of(context).textTheme.titleSmall,
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
          offsetSeconds: widget.item.offsetSeconds,
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
      child: Scrollbar(
        controller: controller,
        thumbVisibility: true,
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
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: context.appColors.textSecondary,
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

class _PreviewActionTile extends StatelessWidget {
  const _PreviewActionTile({
    required this.label,
    required this.icon,
    this.onTap,
    this.isLoading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tokens = context.appComponentTokens;
    return SizedBox(
      width: 120,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: context.appRadius.mdBorder,
          onTap: isLoading ? null : onTap,
          child: Ink(
            padding: EdgeInsets.symmetric(
              horizontal: context.appSpacing.md,
              vertical: context.appSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: context.appRadius.mdBorder,
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child:
                      isLoading
                          ? const CircularProgressIndicator(strokeWidth: 2)
                          : Icon(
                            icon,
                            size: tokens.iconSizeMd,
                            color: colors.textPrimary,
                          ),
                ),
                SizedBox(height: context.appSpacing.sm),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color:
                        onTap == null ? colors.textMuted : colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
