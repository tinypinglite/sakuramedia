import 'package:sakuramedia/features/status/presentation/providers/server_capabilities_provider.dart';
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/clips/presentation/widgets/create_clip_dialog.dart';
import 'package:sakuramedia/features/movies/data/dto/thumbnails/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_thumbnail_provider.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_detail_dto.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_mutation_events_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/videos_api_provider.dart';
import 'package:sakuramedia/features/videos/presentation/video_display_title.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_error_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_action_menu.dart';
import 'package:sakuramedia/widgets/base/overlays/app_action_menu.dart';
import 'package:sakuramedia/widgets/domain/media/media_thumbnail_action_support.dart';
import 'package:sakuramedia/widgets/domain/media/media_thumbnail_tab.dart';

class VideoThumbnailContent extends ConsumerStatefulWidget {
  const VideoThumbnailContent({
    super.key,
    required this.videoId,
    required this.thumbnailPreviewPresentation,
    required this.onSearchSimilar,
    required this.onPlay,
    this.mobileLayout = false,
    this.useGlassChrome = false,
  });

  final int videoId;
  final AppAdaptiveModalVariant thumbnailPreviewPresentation;
  final Future<void> Function(String imageUrl, String fileName) onSearchSimilar;
  final Future<void> Function(int offsetSeconds) onPlay;

  /// 移动端把视频标题提升为页面主标题，并补一行时长 / 媒体数元信息。
  final bool mobileLayout;

  /// 移动端缩略图控制条使用液态玻璃分组。
  final bool useGlassChrome;

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
          _errorMessage = AppLocalizations.of(context).videoNoAvailableMedia;
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
        _errorMessage = apiErrorMessage(
          error,
          fallback: AppLocalizations.of(context).videoLoadFailed,
          l10n: AppLocalizations.of(context),
        );
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
    final action = await showAppActionMenu<AppImageActionType>(
      context: context,
      globalPosition: globalPosition,
      items: buildImageActionMenuItems(
        buildMediaThumbnailActionDescriptors(
          l10n: AppLocalizations.of(context),
          showSearchSimilar: ref.read(imageSearchEnabledProvider),
          thumbnail: thumbnail,
          point: point,
          canSetCover: true,
        ),
      ),
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
        thumbnail.image.origin,
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
      showToast(
        AppLocalizations.of(context).videoCoverSet,
        tone: AppToastTone.success,
      );
    } catch (error) {
      if (mounted) {
        showToast(
          apiErrorMessage(
            error,
            fallback: AppLocalizations.of(context).videoCoverSetFailed,
            l10n: AppLocalizations.of(context),
          ),
          tone: AppToastTone.error,
        );
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
      movieNumber: video.displayTitle(AppLocalizations.of(context)),
      startThumbnailId: start.thumbnailId,
      endThumbnailId: end.thumbnailId,
      startSeconds: start.offsetSeconds,
      endSeconds: end.offsetSeconds,
    );
    if (!mounted || created == null) {
      return;
    }
    showToast(
      AppLocalizations.of(context).videoClipCreated,
      tone: AppToastTone.success,
    );
    _thumbnailController.toggleClipSelectionMode();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: AppInlineSpinner());
    }
    if (_errorMessage != null || _video == null || _mediaId == null) {
      final l10n = AppLocalizations.of(context);
      return Center(
        child: AppErrorState(
          title: l10n.videoLoadFailed,
          message: _errorMessage ?? l10n.videoDetailLoadFailed,
          onRetry: () => unawaited(_load()),
          retryLabel: l10n.videoReload,
          retryKey: const Key('video-thumbnail-retry'),
        ),
      );
    }

    final l10n = AppLocalizations.of(context);
    final metadata = <String>[
      if (_video!.durationSeconds > 0)
        formatMediaTimecode(_video!.durationSeconds),
      if (_video!.mediaItems.isNotEmpty)
        l10n.videoMediaCount(_video!.mediaItems.length),
    ].join(' · ');
    return Column(
      key: const Key('video-thumbnail-page'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: context.appSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _video!.displayTitle(l10n),
                key: const Key('video-thumbnail-title'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: resolveAppTextStyle(
                  context,
                  size: widget.mobileLayout ? AppTextSize.s24 : AppTextSize.s18,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                  height: widget.mobileLayout ? 1.12 : null,
                ),
              ),
              if (widget.mobileLayout && metadata.isNotEmpty) ...[
                SizedBox(height: context.appSpacing.xs),
                Text(
                  metadata,
                  key: const Key('video-thumbnail-metadata'),
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.secondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: MediaThumbnailTab(
            keyPrefix: 'video-thumbnail',
            mediaId: _mediaId,
            glassChrome: widget.useGlassChrome,
            thumbnailPreviewPresentation: widget.thumbnailPreviewPresentation,
            onThumbnailMenuRequested: _showThumbnailActions,
            onCreateClip: _createClip,
          ),
        ),
      ],
    );
  }
}
