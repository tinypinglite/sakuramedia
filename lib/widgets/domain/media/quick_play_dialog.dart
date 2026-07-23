import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/videos/data/api/videos_api.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/media/video/themed_video_player.dart';
import 'package:sakuramedia/widgets/base/media/video/throttling_player.dart';
import 'package:sakuramedia/widgets/base/media/video/video_loading_indicator.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

/// 「点小图 → 弹小窗立刻播」的桌面轻量播放弹窗。
///
/// 切片、视频列表卡、时刻缩略图都走它——两处原本各有一份逐字相同的
/// dialog 实现,差别只在如何拿到 stream URL(切片自带 `stream_url`,
/// 视频列表卡要 `GET /videos/{id}` 取首个可播源)。resolver 参数把
/// 这个差异吃进来。
///
/// 完整观看仍走各自域的独立播放页(自持 seek / subtitle / progress-report)。
class QuickPlayDialog extends StatefulWidget {
  const QuickPlayDialog({
    super.key,
    required this.title,
    required this.fallbackTitle,
    required this.videoKey,
    required this.resolvePlayUrl,
    required this.noPlayableMessage,
    this.errorFallback = '加载失败，请重试',
    this.guardInitialSeek = false,
    this.subtitle,
  });

  final String title;

  /// 标题 trim 后为空时的兜底文案('切片' / '视频' 等)。
  final String fallbackTitle;

  /// 内部 [ThemedVideoPlayer] 的 videoKey——测试锚点,原两 dialog 各有各的值。
  final Key videoKey;

  /// 拿到实际播放地址;返回 null / 空 = 无可播,弹 [AppEmptyState]。
  final Future<String?> Function(BuildContext context) resolvePlayUrl;

  /// resolvePlayUrl 返回 null / 空时的空态文案。
  final String noPlayableMessage;

  /// resolvePlayUrl throw 时的兜底错误文案。
  final String errorFallback;

  /// 完整媒体启用初始化 seek 保护；切片是本地产物，保持关闭。
  final bool guardInitialSeek;

  /// 标题下方的可选副内容槽（例如「所属合集」chip 行）。为空则不留空隙。
  final Widget? subtitle;

  @override
  State<QuickPlayDialog> createState() => _QuickPlayDialogState();
}

class _QuickPlayDialogState extends State<QuickPlayDialog> {
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
    try {
      final resolvedUrl = await widget.resolvePlayUrl(context);
      if (!mounted) {
        return;
      }
      if (resolvedUrl == null || resolvedUrl.isEmpty) {
        setState(() {
          _loading = false;
          _errorMessage = widget.noPlayableMessage;
        });
        return;
      }
      final player = ThrottlingPlayer();
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
        _errorMessage = apiErrorMessage(error, fallback: widget.errorFallback);
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
              title.isEmpty ? widget.fallbackTitle : title,
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
          if (widget.subtitle != null) ...[
            SizedBox(height: spacing.sm),
            widget.subtitle!,
          ],
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
      return const Center(child: VideoLoadingIndicator());
    }
    return ThemedVideoPlayer(
      videoController: controller,
      useTouchOptimizedControls: false,
      guardInitialSeek: widget.guardInitialSeek,
      videoKey: widget.videoKey,
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

/// 视频列表卡 / 时刻卡「小图快播」入口——先取详情、拿首个可播源。
///
/// [subtitle] 是标题下方的可选副内容槽，由调用方组装（例如 videos feature
/// 页面塞 `VideoCollectionChips` 展示所属合集，并在 chip 点击回调里
/// `Navigator.of(context, rootNavigator: true).pop()` 先关 dialog 再跳转）。
/// moments 等无附加上下文的入口留空即可。
Future<void> showVideoQuickPlayDialog(
  BuildContext context, {
  required int videoId,
  required String title,
  Widget? subtitle,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => QuickPlayDialog(
      title: title,
      fallbackTitle: '视频',
      videoKey: const Key('video-quick-play-video'),
      noPlayableMessage: '暂无可播放的媒体',
      guardInitialSeek: true,
      subtitle: subtitle,
      resolvePlayUrl: (innerContext) async {
        final videosApi = innerContext.read<VideosApi>();
        final baseUrl = innerContext.read<SessionStore>().baseUrl;
        final detail = await videosApi.getVideoDetail(videoId: videoId);
        for (final media in detail.mediaItems) {
          if (!media.hasPlayableUrl) {
            continue;
          }
          final resolved = resolveMediaUrl(
            rawUrl: media.playUrl,
            baseUrl: baseUrl,
          );
          if (resolved != null && resolved.isNotEmpty) {
            return resolved;
          }
        }
        return null;
      },
    ),
  );
}
