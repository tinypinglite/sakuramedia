import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/external_player/presentation/external_playback_launcher.dart';
import 'package:sakuramedia/features/videos/presentation/providers/videos_api_provider.dart';

/// 尝试把单个 PornBox 视频交给已配置的外部播放器。
Future<bool> tryLaunchExternalVideoPlayback(
  BuildContext context, {
  required int videoId,
  required String title,
}) {
  return tryLaunchConfiguredExternalPlayer(
    context,
    title: title.trim().isEmpty ? '视频' : title,
    resolveUrl: () => resolveVideoPlaybackUrl(context, videoId: videoId),
  );
}

/// 取得单个 PornBox 视频首个可播放媒体的绝对地址。
///
/// 外部播放器和桌面快播弹窗复用同一解析规则，避免两种播放方式选中不同媒体。
Future<String?> resolveVideoPlaybackUrl(
  BuildContext context, {
  required int videoId,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final detail = await container
      .read(videosApiProvider)
      .getVideoDetail(videoId: videoId);
  final baseUrl = container.read(sessionStoreProvider).baseUrl;
  for (final media in detail.mediaItems) {
    if (!media.hasPlayableUrl) {
      continue;
    }
    final resolved = resolveMediaUrl(rawUrl: media.playUrl, baseUrl: baseUrl);
    if (resolved != null && resolved.isNotEmpty) {
      return resolved;
    }
  }
  return null;
}
