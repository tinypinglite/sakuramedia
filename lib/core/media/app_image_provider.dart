import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:material_ui/material_ui.dart';

/// 应用统一的图片磁盘缓存：只服务封面/头像等需要长期复用的图片。
///
/// 沿用 `libCachedImageData` 作为 cacheKey，避免更换 key 时旧缓存目录变成孤儿。
class AppImageCacheManager extends CacheManager with ImageCacheManager {
  static const String key = 'libCachedImageData';

  static final AppImageCacheManager instance = AppImageCacheManager._();

  AppImageCacheManager._()
    : super(
        Config(
          key,
          maxNrOfCacheObjects: 1024,
          stalePeriod: const Duration(days: 30),
        ),
      );
}

/// 不落盘的图片路径特征：剧情图、媒体点缩略图、元数据搜索图。
const List<String> _transientPathMarkers = <String>[
  '/thumbnails/',
  '/plot-',
  '/metadata-search/',
];

bool isTransientImage(String url) {
  final path = Uri.tryParse(url)?.path ?? url;
  return _transientPathMarkers.any(path.contains);
}

/// 去掉签名参数后的稳定缓存 key，使缓存不随 `expires`/`signature` 轮换失效。
String stableImageCacheKey(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasQuery) {
    return url;
  }
  final params = Map<String, String>.of(uri.queryParameters)
    ..remove('expires')
    ..remove('signature');
  if (params.isEmpty) {
    return url.substring(0, url.indexOf('?'));
  }
  return uri.replace(queryParameters: params).toString();
}

/// 预览/测试注入点：注册过的 URL 直接返回本地图片 provider，绕开
/// [CachedNetworkImageProvider]（测试环境没有 path_provider / sqflite）。
/// 生产环境恒为空，行为不变；注册与清理见 `test/support/preview_helpers.dart`。
@visibleForTesting
final Map<String, ImageProvider<Object>> debugRemoteImageOverrides =
    <String, ImageProvider<Object>>{};

/// 统一的远端图片 provider 工厂。
///
/// - 封面/头像：`CachedNetworkImageProvider` + 稳定 cacheKey → 跨签名窗口命中；
/// - 剧情图/缩略图/搜索图：`NetworkImage` → 只走内存缓存，不落盘。
ImageProvider<Object> buildRemoteImageProvider(String url) {
  final override = debugRemoteImageOverrides[url];
  if (override != null) {
    return override;
  }
  if (isTransientImage(url)) {
    return NetworkImage(url);
  }
  return CachedNetworkImageProvider(
    url,
    cacheKey: stableImageCacheKey(url),
    cacheManager: AppImageCacheManager.instance,
  );
}
