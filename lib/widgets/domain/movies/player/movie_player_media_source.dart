import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// 播放来源类型:决定错误文案与播放信息面板里的来源诊断展示。
enum MoviePlayerMediaSourceKind { local, cloud115, unknown }

const String moviePlayerUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/125.0.0.0 Safari/537.36';

Media buildMoviePlayerMedia(
  String resolvedUrl, {
  Duration? startPosition,
  bool isWeb = kIsWeb,
}) {
  return Media(
    resolvedUrl,
    start: startPosition,
    httpHeaders: isWeb
        ? null
        : const <String, String>{'User-Agent': moviePlayerUserAgent},
  );
}

String moviePlayerPlaybackErrorMessage(MoviePlayerMediaSourceKind sourceKind) {
  return switch (sourceKind) {
    MoviePlayerMediaSourceKind.cloud115 =>
      '暂时无法播放此 115 网盘媒体。请检查网络或媒体库认证状态；如需重新认证，请前往「系统设置 → 媒体库」。',
    MoviePlayerMediaSourceKind.local => '暂时无法播放此媒体。请检查媒体文件是否仍然可用。',
    MoviePlayerMediaSourceKind.unknown => '暂时无法播放此媒体。',
  };
}

PlayerConfiguration buildMoviePlayerConfiguration({
  bool isWeb = kIsWeb,
  TargetPlatform? platform,
}) {
  if (isWeb) {
    return const PlayerConfiguration();
  }

  switch (platform ?? defaultTargetPlatform) {
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      return const PlayerConfiguration(libass: true);
    default:
      return const PlayerConfiguration();
  }
}
