import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/videos/data/api/videos_api.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/media_player/themed_video_player.dart';

/// 列表卡片「播放」icon 的轻量弹窗播放器：拉一次详情取默认（首个可播）媒体源，
/// 用 media_kit 直接播放，无缩略图/字幕/进度上报。完整观看仍走详情页的独立播放页。
///
/// 与 [ClipPlayerDialog] 平行，区别是切片自带签名 `stream_url`，而视频列表项不含
/// 播放地址，需先 `GET /videos/{id}` 拿 `media_items` 再解析首个可播源。
Future<void> showVideoQuickPlayDialog(
  BuildContext context, {
  required int videoId,
  required String title,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) =>
        VideoQuickPlayDialog(videoId: videoId, title: title),
  );
}

class VideoQuickPlayDialog extends StatefulWidget {
  const VideoQuickPlayDialog({
    super.key,
    required this.videoId,
    required this.title,
  });

  final int videoId;
  final String title;

  @override
  State<VideoQuickPlayDialog> createState() => _VideoQuickPlayDialogState();
}

class _VideoQuickPlayDialogState extends State<VideoQuickPlayDialog> {
  Player? _player;
  VideoController? _controller;
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final videosApi = context.read<VideosApi>();
    final baseUrl = context.read<SessionStore>().baseUrl;
    try {
      final detail = await videosApi.getVideoDetail(videoId: widget.videoId);
      if (!mounted) {
        return;
      }
      String? resolvedUrl;
      for (final media in detail.mediaItems) {
        if (!media.hasPlayableUrl) {
          continue;
        }
        resolvedUrl = resolveMediaUrl(rawUrl: media.playUrl, baseUrl: baseUrl);
        if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
          break;
        }
      }
      if (resolvedUrl == null || resolvedUrl.isEmpty) {
        setState(() {
          _loading = false;
          _errorMessage = '暂无可播放的媒体';
        });
        return;
      }
      final player = Player();
      final controller = VideoController(
        player,
        configuration: const VideoControllerConfiguration(hwdec: 'auto'),
      );
      setState(() {
        _loading = false;
        _player = player;
        _controller = controller;
      });
      player.open(Media(resolvedUrl));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = apiErrorMessage(error, fallback: '加载失败，请重试');
      });
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final title = widget.title.trim();
    return AppDesktopDialog(
      width: context.appComponentTokens.clipPlayerDialogWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(right: spacing.xl),
            child: Text(
              title.isEmpty ? '视频' : title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s16,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.primary,
              ),
            ),
          ),
          SizedBox(height: spacing.md),
          ClipRRect(
            borderRadius: context.appRadius.smBorder,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: Colors.black,
                child: _buildVideo(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideo() {
    if (_errorMessage != null) {
      return Center(child: AppEmptyState(message: _errorMessage!));
    }
    final controller = _controller;
    if (_loading || controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ThemedVideoPlayer(
      videoController: controller,
      useTouchOptimizedControls: false,
      videoKey: const Key('video-quick-play-video'),
      bottomControls: const <Widget>[
        MaterialPlayOrPauseButton(),
        MaterialDesktopVolumeButton(),
        MaterialPositionIndicator(),
        Spacer(),
        MaterialFullscreenButton(),
      ],
    );
  }
}
