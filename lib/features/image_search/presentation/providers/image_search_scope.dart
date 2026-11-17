import 'package:flutter/foundation.dart';

/// 以完整路由 location 区分图搜页面实例，延续旧页面缓存的动态 key 语义。
@immutable
class ImageSearchScope {
  const ImageSearchScope(this.cacheKey);

  final String cacheKey;

  @override
  bool operator ==(Object other) =>
      other is ImageSearchScope && other.cacheKey == cacheKey;

  @override
  int get hashCode => cacheKey.hashCode;
}
