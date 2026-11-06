import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:media_kit/media_kit.dart';

const String moviePlayerUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/125.0.0.0 Safari/537.36';

Media buildMoviePlayerMedia(String resolvedUrl, {Duration? startPosition}) {
  return Media(
    resolvedUrl,
    start: startPosition,
    httpHeaders: const <String, String>{'User-Agent': moviePlayerUserAgent},
  );
}

PlayerConfiguration buildMoviePlayerConfiguration({TargetPlatform? platform}) {
  switch (platform ?? defaultTargetPlatform) {
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      return const PlayerConfiguration(libass: true);
    default:
      return const PlayerConfiguration();
  }
}
