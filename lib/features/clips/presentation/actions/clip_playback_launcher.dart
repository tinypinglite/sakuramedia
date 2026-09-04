import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/external_player/presentation/external_playback_launcher.dart';

/// 尝试把单个切片交给已配置的外部播放器。
Future<bool> tryLaunchExternalClipPlayback(
  BuildContext context, {
  required String streamUrl,
  required String title,
}) {
  return tryLaunchConfiguredExternalPlayer(
    context,
    title: title.trim().isEmpty ? '切片' : title,
    resolveUrl: () async =>
        resolveClipPlaybackUrl(context, streamUrl: streamUrl),
  );
}

/// 将后端返回的切片地址补成可播放的绝对地址。
String? resolveClipPlaybackUrl(
  BuildContext context, {
  required String streamUrl,
}) {
  final baseUrl = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(sessionStoreProvider).baseUrl;
  return resolveMediaUrl(rawUrl: streamUrl, baseUrl: baseUrl);
}
