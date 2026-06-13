import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';

/// 轻量切片播放弹层：用 media_kit 直接播放切片的签名 `stream_url`。
///
/// 切片很短，无需缩略图/进度上报/字幕，因此不复用重型的 [MoviePlayerSurface]。
Future<void> showClipPlayerDialog(
  BuildContext context, {
  required String streamUrl,
  required String title,
}) {
  return showDialog<void>(
    context: context,
    builder:
        (dialogContext) => ClipPlayerDialog(streamUrl: streamUrl, title: title),
  );
}

class ClipPlayerDialog extends StatefulWidget {
  const ClipPlayerDialog({
    super.key,
    required this.streamUrl,
    required this.title,
  });

  final String streamUrl;
  final String title;

  @override
  State<ClipPlayerDialog> createState() => _ClipPlayerDialogState();
}

class _ClipPlayerDialogState extends State<ClipPlayerDialog> {
  Player? _player;
  VideoController? _controller;
  bool _hasResolvedUrl = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  void _open() {
    final baseUrl = context.read<SessionStore>().baseUrl;
    final resolvedUrl = resolveMediaUrl(
      rawUrl: widget.streamUrl,
      baseUrl: baseUrl,
    );
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      setState(() => _hasResolvedUrl = false);
      return;
    }
    final player = Player();
    final controller = VideoController(
      player,
      configuration: const VideoControllerConfiguration(hwdec: 'auto'),
    );
    setState(() {
      _player = player;
      _controller = controller;
    });
    player.open(Media(resolvedUrl));
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return AppDesktopDialog(
      width: context.appComponentTokens.clipPlayerDialogWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(right: spacing.xl),
            child: Text(
              widget.title.trim().isEmpty ? '切片' : widget.title.trim(),
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
    if (!_hasResolvedUrl) {
      return const Center(child: AppEmptyState(message: '无效的播放地址'));
    }
    final controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Video(
      key: const Key('clip-player-video'),
      controller: controller,
      fit: BoxFit.contain,
      fill: Colors.black,
    );
  }
}
