import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AppImageConfig {
  static const int imageCacheMaximumSize = 400;
  static const int imageCacheMaximumSizeBytes = 64 * 1024 * 1024;

  static final CacheManager networkImageCacheManager = CacheManager(
    Config(
      'sakuramedia_image_cache',
      maxNrOfCacheObjects: 10000,
      maxCacheSize: 512 * 1024 * 1024,
    ),
  );

  static bool enableBlur = false;
  static double blurSigma = 30;

  @Deprecated('Use enableBlur instead.')
  static bool get enableMask => enableBlur;

  @Deprecated('Use enableBlur instead.')
  static set enableMask(bool value) => enableBlur = value;
}
