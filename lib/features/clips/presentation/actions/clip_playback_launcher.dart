import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/clips/presentation/pages/mobile/clip_player_page.dart';
import 'package:sakuramedia/features/external_player/presentation/external_playback_launcher.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/overlays/app_dialog.dart';
import 'package:sakuramedia/widgets/domain/media/quick_play_dialog.dart';

/// 切片播放入口（桌面 / 移动统一）：已配置外部播放器时优先交给它；否则移动端
/// 推全屏横屏 [MobileClipPlayerPage]，桌面弹 [QuickPlayDialog] 轻量弹窗。
Future<void> launchClipPlayback(
  BuildContext context, {
  required String streamUrl,
  required String title,
}) async {
  if (await _tryLaunchExternalClipPlayback(
    context,
    streamUrl: streamUrl,
    title: title,
  )) {
    return;
  }
  if (!context.mounted) {
    return;
  }
  if (isMobileAppPlatform()) {
    // 用根 Navigator 推全屏页，覆盖底部导航；切片自带 streamUrl 直接传入，
    // 无需经 go_router 把签名地址放进 URL。
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MobileClipPlayerPage(streamUrl: streamUrl, title: title),
      ),
    );
    return;
  }
  await showAppDialog<void>(
    context: context,
    builder: (dialogContext) => QuickPlayDialog(
      title: title,
      fallbackTitle: AppLocalizations.of(context).clipFallbackTitle,
      videoKey: const Key('clip-player-video'),
      noPlayableMessage: AppLocalizations.of(context).clipInvalidPlaybackUrl,
      resolveMedia: (innerContext) async {
        final url = _resolveClipPlaybackUrl(innerContext, streamUrl: streamUrl);
        return url == null ? null : QuickPlayMedia(url);
      },
    ),
  );
}

/// 尝试把单个切片交给已配置的外部播放器。
Future<bool> _tryLaunchExternalClipPlayback(
  BuildContext context, {
  required String streamUrl,
  required String title,
}) {
  return tryLaunchConfiguredExternalPlayer(
    context,
    title: title.trim().isEmpty
        ? AppLocalizations.of(context).clipFallbackTitle
        : title,
    resolveUrl: () async =>
        _resolveClipPlaybackUrl(context, streamUrl: streamUrl),
  );
}

/// 将后端返回的切片地址补成可播放的绝对地址。
String? _resolveClipPlaybackUrl(
  BuildContext context, {
  required String streamUrl,
}) {
  final baseUrl = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(sessionStoreProvider).baseUrl;
  return resolveMediaUrl(rawUrl: streamUrl, baseUrl: baseUrl);
}
