import 'package:flutter/foundation.dart';

/// 榜单页的缓存身份。桌面和移动原先各自拥有一个 page-state entry，迁移后仍以
/// family 分隔筛选、分页与滚动宿主，避免两个端之间互相污染。
@immutable
class RankingSummaryScope {
  const RankingSummaryScope._(this.cacheKey);

  const RankingSummaryScope.desktop() : this._('desktop:rankings:list');
  const RankingSummaryScope.mobile() : this._('mobile:rankings:list');

  final String cacheKey;

  bool get isMobile => this == const RankingSummaryScope.mobile();

  @override
  bool operator ==(Object other) =>
      other is RankingSummaryScope && other.cacheKey == cacheKey;

  @override
  int get hashCode => cacheKey.hashCode;
}
