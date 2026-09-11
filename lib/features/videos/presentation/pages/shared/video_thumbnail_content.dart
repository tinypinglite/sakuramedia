import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/clips/presentation/widgets/create_clip_dialog.dart';
import 'package:sakuramedia/features/movies/data/dto/thumbnails/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_thumbnail_provider.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_plot_preview_overlay.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_detail_dto.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_mutation_events_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/videos_api_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_action_menu.dart';
import 'package:sakuramedia/widgets/domain/media/media_thumbnail_action_support.dart';
import 'package:sakuramedia/widgets/domain/media/media_thumbnail_tab.dart';

class VideoThumbnailContent extends ConsumerStatefulWidget {
  const VideoThumbnailContent({
    super.key,
    required this.videoId,
    required this.thumbnailPreviewPresentation,
    required this.onSearchSimilar,
    required this.onPlay,
  });

  final int videoId;
  final MoviePlotPreviewPresentation thumbnailPreviewPresentation;
  final Future<void> Function(String imageUrl, String fileName) onSearchSimilar;
  final Future<void> Function(int offsetSeconds) onPlay;

  @override
  ConsumerState<VideoThumbnailContent> createState() =>
      _VideoThumbnailContentState();
}

class _VideoThumbnailContentState extends ConsumerState<VideoThumbnailContent> {
  VideoItemDetailDto? _video;
  int? _mediaId;
  String? _errorMessage;
  bool _isLoading = true;
  KeepAliveLink? _thumbnailLink;
  int _loadRequest = 0;

  MovieDetailThumbnail get _thumbnailController =>
      ref.read(movieDetailThumbnailProvider(mediaId: _mediaId).notifier);

  MovieDetailThumbnailState get _thumbnailState =>
      ref.read(movieDetailThumbnailProvider(mediaId: _mediaId));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_load());
      }
    });
  }

  @override
  void dispose() {
    _thumbnailLink?.close();
    _thumbnailLink = null;
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_loadRequest;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final api = ref.read(videosApiProvider);
      final detail = await api.getVideoDetail(videoId: widget.videoId);
      if (!mounted || request != _loadRequest) {
        return;
      }
      if (detail.mediaItems.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = '该视频暂无可用媒体';
        });
        return;
      }

      final media = detail.mediaItems.first;
      final controller = ref.read(
        movieDetailThumbnailProvider(mediaId: media.mediaId).notifier,
      );
      _thumbnailLink = controller.cacheLink;
      _mediaId = media.mediaId;
      _video = detail;
      setState(() {
        _isLoading = false;
      });
      unawaited(controller.loadIfNeeded());
    } catch (error) {
      if (!mounted || request != _loadRequest) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = apiErrorMessage(error, fallback: '加载失败，请重试');
      });
    }
  }

  Future<void> _showThumbnailActions(int index, Offset globalPosition) async {
    final thumbnails = _thumbnailState.thumbnails;
    if (index < 0 || index >= thumbnails.length) {
      return;
    }
    final thumbnail = thumbnails[index];
    final point = await findMediaPointForThumbnail(
      ref: ref,
      thumbnail: thumbnail,
    );
    if (!mounted) {
      return;
    }
    final action = await showAppImageActionMenu(
      context: context,
      actions: buildMediaThumbnailActionDescriptors(
        thumbnail: thumbnail,
        point: point,
        canSetCover: true,
      ),
      globalPosition: globalPosition,
      presentation: AppImageActionMenuPresentation.auto,
    );
    if (!mounted || action == null) {
      return;
    }
    await handleMediaThumbnailAction(
      context: context,
      ref: ref,
      thumbnail: thumbnail,
      action: action,
      point: point,
      fileName:
          'video_thumbnail_${widget.videoId}_${thumbnail.thumbnailId}.webp',
      onSearchSimilar: () => widget.onSearchSimilar(
        thumbnail.image.resolvedUrl,
        'video_thumbnail_${widget.videoId}_${thumbnail.thumbnailId}.webp',
      ),
      onPlay: () => widget.onPlay(thumbnail.offsetSeconds),
      onSetCover: () => _setCover(thumbnail),
    );
  }

  Future<void> _setCover(MovieMediaThumbnailDto thumbnail) async {
    try {
      await ref
          .read(videosApiProvider)
          .setVideoCover(
            videoId: widget.videoId,
            thumbnailId: thumbnail.thumbnailId,
          );
      if (!mounted) {
        return;
      }
      ref
          .read(videoMutationEventsProvider.notifier)
          .reportCoverChanged(videoId: widget.videoId);
      showToast('已设为封面');
    } catch (error) {
      if (mounted) {
        showToast(apiErrorMessage(error, fallback: '设置封面失败，请重试'));
      }
    }
  }

  Future<void> _createClip() async {
    final state = _thumbnailState;
    final start = state.clipStartThumbnail;
    final end = state.clipEndThumbnail;
    final video = _video;
    if (start == null || end == null || video == null) {
      return;
    }
    final created = await showCreateClipDialog(
      context,
      mediaId: start.mediaId,
      movieNumber: video.preferredTitle,
      startThumbnailId: start.thumbnailId,
      endThumbnailId: end.thumbnailId,
      startSeconds: start.offsetSeconds,
      endSeconds: end.offsetSeconds,
    );
    if (!mounted || created == null) {
      return;
    }
    showToast('切片已生成');
    _thumbnailController.toggleClipSelectionMode();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null || _video == null || _mediaId == null) {
      return Center(
        child: AppEmptyState(
          message: _errorMessage ?? '视频详情暂时无法加载，请重试',
          onRetry: () => unawaited(_load()),
          retryLabel: '重新加载',
          retryKey: const Key('video-thumbnail-retry'),
        ),
      );
    }

    return Column(
      key: const Key('video-thumbnail-page'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: context.appSpacing.sm),
          child: Text(
            _video!.preferredTitle,
            key: const Key('video-thumbnail-title'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s18,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
        ),
        Expanded(
          child: MediaThumbnailTab(
            keyPrefix: 'video-thumbnail',
            mediaId: _mediaId,
            thumbnailPreviewPresentation: widget.thumbnailPreviewPresentation,
            onThumbnailMenuRequested: _showThumbnailActions,
            onCreateClip: _createClip,
          ),
        ),
      ],
    );
  }
}
