import 'package:flutter/foundation.dart';

/// 搜索页的缓存身份。
///
/// 同一宿主的不同搜索路由原先以完整 location 分别缓存 entry；family 延续这条
/// 边界，保证历史搜索结果、开关与在途流不会串到另一个查询页。
@immutable
class CatalogSearchScope {
  const CatalogSearchScope(this.cacheKey);

  final String cacheKey;

  @override
  bool operator ==(Object other) =>
      other is CatalogSearchScope && other.cacheKey == cacheKey;

  @override
  int get hashCode => cacheKey.hashCode;
}
