import 'package:flutter/foundation.dart';

/// 演员列表页面的缓存身份。
///
/// 桌面和移动端原先分别持有 `desktop:actors:list` / `mobile:actors:list`
/// 两个 page-state entry；family 继续保持这两个独立缓存槽，避免一个宿主的
/// 筛选、分页或滚动状态意外串到另一个宿主。
@immutable
class ActorSummaryScope {
  const ActorSummaryScope._(this.cacheKey);

  const ActorSummaryScope.desktop() : this._('desktop:actors:list');
  const ActorSummaryScope.mobile() : this._('mobile:actors:list');

  final String cacheKey;

  @override
  bool operator ==(Object other) =>
      other is ActorSummaryScope && other.cacheKey == cacheKey;

  @override
  int get hashCode => cacheKey.hashCode;
}
