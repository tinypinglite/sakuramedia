import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/widgets/domain/media/quick_play_dialog.dart';

/// 轻量切片播放弹层:用签名 `stream_url` 直接 media_kit 播。
///
/// 切片很短、无需缩略图 / 进度上报 / 字幕,与视频列表卡「小图快播」
/// 共用同一套骨架 [QuickPlayDialog];resolver 是同步的 base URL 拼接。
Future<void> showClipPlayerDialog(
  BuildContext context, {
  required String streamUrl,
  required String title,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => QuickPlayDialog(
      title: title,
      fallbackTitle: '切片',
      videoKey: const Key('clip-player-video'),
      noPlayableMessage: '无效的播放地址',
      resolvePlayUrl: (innerContext) async {
        final baseUrl = innerContext.read<SessionStore>().baseUrl;
        return resolveMediaUrl(rawUrl: streamUrl, baseUrl: baseUrl);
      },
    ),
  );
}
